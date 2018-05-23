require 'aix/errlog/constants'
require 'aix/errlog/lib'
require 'aix/errlog/entry'
require 'aix/errlog/errors'
require 'aix/errlog/match'

module AIX
  module Errlog
    ##
    # Simple convenince shortcut to access AIX::Errlog::Errlog.open
    def self.open(*args, &block)
      ::AIX::Errlog::Errlog.open(*args, &block)
    end

    ##
    # The core errlog class.  Used to open an errlog file.
    #
    # The main method that should be used here is ::open (more likely
    # AIX::Errlog.open for convenience), and the block form is strongly
    # recommended wherever possible.  If you do not use the block form, make
    # sure you call #close when you are done with it (enforce it with an ensure
    # block if possible).  The garbage collector will not do this automatically,
    # and you can leak.
    #
    # #forward_each and #reverse_each should do everything you need to do.  If
    # you use the enumerator form, or even the block form of these, make sure
    # you consume the entire enumerator before opening a new one.  If you need
    # to enumerate the errlog in a nested loop or something like that, you'll
    # need multuple instances of this open, otherwise it will fail (the handle
    # operates as a cursor, so if you try to re-invoke one before it is
    # finished, the cursor will get reset, and you'll get jumbled results).
    # While one of these enumerators as active, trying to re-invoke one will
    # raise an EnumeratorError.
    #
    # If you need to do complex matching, use the #match_* methods in here to
    # create Match objects to work with.  You can see Match for more details as
    # to how to create those.
    #
    # A simple example, showing how to get a list of all labels of all log
    # entries in forward order which contain the string 'KILL' in their label
    # and happen in the month of January 2017, and which have a sequence ID
    # above 1000, or that happen in December 2016 and have a sequence ID below
    # 500, might look something like this:
    #
    #   require 'date'
    #
    #   require 'aix/errlog'
    #
    #   AIX::Errlog.open do |log|
    #     log.forward_each(match: (
    #       log.match_label.include?('KILL') & (
    #         (
    #           (log.match_sequence > 1000) &
    #           (log.match_timestamp >= DateTime.new(2017, 1, 1)) &
    #           (log.match_timestamp < DateTime.new(2017, 2, 1))
    #         ) | (
    #           (log.match_sequence < 500) &
    #           (log.match_timestamp >= DateTime.new(2016, 12, 1)) &
    #           (log.match_timestamp < DateTime.new(2017, 1, 1))
    #         )
    #       )
    #     )).map(&:label)
    #   end
    #
    # Certainly, that looks a little complex, but it is a bit more efficient
    # than iterating all log entries as a whole and then filtering after the
    # fact, and it's a lot more pleasant than building the Match tree from
    # scratch in C.
    class Errlog
      ##
      # path is the string path to the file.
      # mode matches as closely as possible to the semantics of the fopen mode.
      def initialize(path='/var/adm/ras/errlog'.freeze, mode='r'.freeze)
        mode_r = mode.include? 'r'
        mode_w = mode.include? 'w'
        mode_a = mode.include? 'a'
        mode_x = mode.include? 'x'
        mode_p = mode.include? '+'

        mode_flags =
          if mode_p
            Constants::O_RDRW
          elsif mode_r
            Constants::O_RDONLY
          else
            Constants::O_WRONLY
          end
        mode_flags |= Constants::O_CREAT unless mode_r
        mode_flags |= Constants::O_TRUNC if mode_w
        mode_flags |= Constants::O_APPEND if mode_a
        mode_flags |= Constants::O_EXCL if mode_x

        handle_p = FFI::MemoryPointer.new(:pointer)

        status = Lib.errlog_open(
          path,
          mode_flags,
          Constants::LE_MAGIC,
          handle_p,
        )

        Errors.throw(status, "path: #{path}, mode: #{mode}") unless status == :ok

        @enum_active = false

        # Just hold the handle directly
        @handle = handle_p.get_pointer
      end

      ##
      # Opens the given error log.  Arguments are passed directly into ::new
      #
      # If a block is given, #close will be automatically called when the block
      # exits, and the return value of the block will be the return value of
      # this.
      def self.open(*args)
        errlog = new(*args)
        if block_given?
          begin
            return yield errlog
          ensure
            errlog.close
          end
        else
          log
        end
      end

      ##
      # Closes the handle.  This must be called, either directly or indirectly
      # through ::open with a block.  This may be called multiple times, but
      # after this is called, no other functions that try to use the errlog
      # handle may be called.
      def close
        unless @handle.nil?
          status = Lib.errlog_close(@handle)
          Errors.throw(status, "handle: #{@handle}") unless status == :ok
          @handle = nil
        end
      end

      ##
      # Enumerate log Entry objects in forward order (default is reverse).  If
      # no block is given, returns an enumerator.
      #
      # sequence specifies the sequence ID to start with.  It will be included
      # in the results if specifed
      #
      # match takes a Match object, which specifies which entries to match.
      #
      # match and sequence must not be both specified.  If neither are
      # specified, this simply iterates from the beginning (or from the previous
      # stopped position, if #find_sequence or #find_first have already been
      # called).
      #
      # An active enumerator can not be nested within another active enumerator,
      # including the block form of this.  If you invoke any of the #each_
      # methods while another has not finished and exited, you'll raise an
      # EnumeratorError.  You can create an enumerator of one within the other,
      # as long as you don't activate it until the first one has exited.
      #
      # Warning: if the sequence does not exist (which is common when error logs
      # are cleaned), no entries will be returned, even if they follow the
      # sequence ID.  If you want all entries based on their sequence number,
      # use match instead.  You're usually better off using the timestamp
      # instead of sequence number, because the sequence number is 32 bits and
      # might wrap.
      def forward_each(match: nil, sequence: nil, &block)
        raise 'match and sequence must not be both specified' if match && sequence

        return to_enum(:forward_each, match: match, sequence: sequence) unless block_given?
        set_direction :forward
        each(match: match, sequence: sequence, &block)
      end

      ##
      # Enumerate log Entry objects in reverse order (default is reverse).  If
      # no block is given, returns an enumerator.
      #
      # sequence specifies the sequence ID to start with.  It will be included
      # in the results if specifed
      #
      # match takes a Match object, which specifies which entries to match.
      #
      # match and sequence must not be both specified.  If neither are
      # specified, this simply iterates from the beginning (or from the previous
      # stopped position, if #find_sequence or #find_first have already been
      # called).
      #
      # An active enumerator can not be nested within another active enumerator,
      # including the block form of this.  If you invoke any of the #each_
      # methods while another has not finished and exited, you'll raise an
      # EnumeratorError.  You can create an enumerator of one within the other,
      # as long as you don't activate it until the first one has exited.
      #
      # Warning: if the sequence does not exist (which is common when error logs
      # are cleaned), no entries will be returned, even if they follow the
      # sequence ID.  If you want all entries based on their sequence number,
      # use match instead.  You're usually better off using the timestamp
      # instead of sequence number, because the sequence number is 32 bits and
      # might wrap.
      def reverse_each(match: nil, sequence: nil, &block)
        raise 'match and sequence must not be both specified' if match && sequence

        return to_enum(:reverse_each, match: match, sequence: sequence) unless block_given?
        set_direction :reverse
        each(match: match, sequence: sequence, &block)
      end

      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # sequence.
      def match_sequence
        Match.new(left: :sequence)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # label.
      def match_label
        Match.new(left: :label)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # timestamp.
      def match_timestamp
        Match.new(left: :timestamp)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # crcid.
      def match_crcid
        Match.new(left: :crcid)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # machineid.
      def match_machineid
        Match.new(left: :machineid)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # nodeid.
      def match_nodeid
        Match.new(left: :nodeid)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # class.
      def match_class
        Match.new(left: :class)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # type.
      def match_type
        Match.new(left: :type)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # resource.
      def match_resource
        Match.new(left: :resource)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # rclass.
      def match_rclass
        Match.new(left: :rclass)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # rtype.
      def match_rtype
        Match.new(left: :rtype)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # vpd_ibm.
      def match_vpd_ibm
        Match.new(left: :vpd_ibm)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # vpd_user.
      def match_vpd_user
        Match.new(left: :vpd_user)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against in.
      def match_in
        Match.new(left: :in)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # connwhere.
      def match_connwhere
        Match.new(left: :connwhere)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # flag_err64.
      def match_flag_err64
        Match.new(left: :flag_err64)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # flag_errdup.
      def match_flag_errdup
        Match.new(left: :flag_errdup)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # detail_data.
      def match_detail_data
        Match.new(left: :detail_data)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # symptom_data.
      def match_symptom_data
        Match.new(left: :symptom_data)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # errdiag.
      def match_errdiag
        Match.new(left: :errdiag)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # wparid.
      def match_wparid
        Match.new(left: :wparid)
      end

      private

      ##
      # Get an entry for the specified sequence, if there is any, and nil
      # otherwise.
      def find_sequence(id)
        entry = Lib::ErrlogEntry.new
        status = Lib.errlog_find_sequence(@handle, id, entry)
        return if status == :done
        Errors.throw(status, "handle: #{@handle}, sequence: #{id}") unless status == :ok

        Entry.new(entry).freeze
      end

      ##
      # Get an entry matching the passed-in Match, if there is any, and nil
      # otherwise.
      def find_first(match)
        entry = Lib::ErrlogEntry.new
        status = Lib.errlog_find_first(@handle, match.to_struct, entry)
        return if status == :done
        Errors.throw(status, "handle: #{@handle}, match: #{match}") unless status == :ok

        Entry.new(entry).freeze
      end

      ##
      # Get the next entry.
      def find_next
        entry = Lib::ErrlogEntry.new
        status = Lib.errlog_find_next(@handle, entry)
        return if status == :done
        Errors.throw(status, "handle: #{@handle}") unless status == :ok
        Entry.new(entry).freeze
      end

      ##
      # Sets the search direction for iteration.
      def set_direction(direction)
        status = Lib.errlog_set_direction(@handle, direction)
        Errors.throw(status, "handle: #{@handle}, direction: #{direction}") unless status == :ok
      end

      ##
      # Enumerate log entries in the order set in #set_direction (default is
      # reverse).
      #
      # sequence specifies the sequence ID to start with.  It will be included
      # in the results if specifed
      #
      # match takes a Match object, which specifies which entries to match.
      #
      # match and sequence must not be both specified.  If neither are
      # specified, this simply iterates from the beginning (or from the previous
      # stopped position, if #find_sequence or #find_first have already been
      # called).
      #
      # An active enumerator can not be nested within another active enumerator,
      # including the block form of this.  If you invoke any of the #each_
      # methods while another has not finished and exited, you'll raise an
      # EnumeratorError.  You can create an enumerator of one within the other,
      # as long as you don't activate it until the first one has exited.
      #
      # Warning: if the sequence does not exist (which is common when error logs
      # are cleaned), no entries will be returned, even if they follow the
      # sequence ID.  If you want all entries based on their sequence number,
      # use match instead.  You're usually better off using the timestamp
      # instead of sequence number, because the sequence number is 32 bits and
      # might wrap.
      #
      # The user-facing entry points to this are #forward_each and #reverse_each
      def each(match: nil, sequence: nil)
        # Does not return an enumerator, because this will always be called with
        # an active block

        begin
          raise Errors::EnumeratorError if @enum_active
          @enum_active = true

          if sequence
            entry = find_sequence(sequence)
            return if entry.nil?
            yield entry
          end

          if match
            entry = find_first(match)
            return if entry.nil?
            yield entry
          end

          while entry = find_next
            yield entry
          end
        ensure
          @enum_active = false
        end
      end
    end
  end
end
