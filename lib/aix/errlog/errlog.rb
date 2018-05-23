require 'aix/errlog/constants'
require 'aix/errlog/lib'
require 'aix/errlog/entry'

module AIX
  module Errlog
    ##
    # The core errlog class.  Used to open an errlog file.
    #
    # The main method that should be used here is ::open, and the block form is
    # strongly recommended wherever possible.  If you do not use the block form,
    # make sure you call #close when you are done with it (enforce it with an
    # ensure block if possible).  The garbage collector will not do this
    # automatically, and you can leak.
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

        # Just hold the handle directly
        @handle = handle_p.get_pointer
      end

      ##
      # Opens the given error log.  Arguments match that of ::new.
      #
      # If a block is given, #close will be automatically called when the block
      # exits, and the return value of the block will be the return value of
      # this.
      def self.open(path='/var/adm/ras/errlog'.freeze, mode='r'.freeze)
        log = new(path, mode)
        if block_given?
          begin
            return yield log
          ensure
            log.close
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
      # Sets the search direction for iteration.  You shouldn't need to call
      # this; it will be called by #forward_each and #reverse_each
      # automatically, which mostly just call this and #each.
      def set_direction(direction)
        status = Lib.errlog_set_direction(@handle, direction)
        Errors.throw(status, "handle: #{@handle}, direction: #{direction}") unless status == :ok
      end

      ##
      # Enumerate log entries in forward order (default is reverse).  If no
      # block is given, returns an enumerator.
      #
      # See #each for more details on available kwargs.
      def forward_each(**kwargs, &block)
        return to_enum(:forward_each, **kwargs) unless block_given?
        set_direction :forward
        each(**kwargs, &block)
      end

      ##
      # Enumerate log entries in reverse order (default is reverse).  If no
      # block is given, returns an enumerator.
      #
      # See #each for more details on available kwargs.
      def reverse_each(**kwargs, &block)
        return to_enum(:reverse_each, **kwargs) unless block_given?
        set_direction :reverse
        each(**kwargs, &block)
      end

      ##
      # Enumerate log entries in the order set in #set_direction (default is
      # reverse).  If no block is given, returns an enumerator.
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
      # Warning: if the sequence does not exist, no entries will be returned,
      # even if they follow the sequence ID.  If you want all entries based on
      # their sequence number, use match instead.  You're usually better off
      # using the timestamp instead.
      def each(match: nil, sequence: nil)
        raise 'match and sequence must not be both specified' if match && sequence

        return to_enum(:each, match: match, sequence: sequence) unless block_given?

        if sequence
          entry = find_sequence(sequence)
          yield entry unless entry.nil?
        end

        loop do
          entry = Lib::ErrlogEntry.new
          status = Lib.errlog_find_next(@handle, entry)
          return if status == :done
          Errors.throw(status, "handle: #{@handle}") unless status == :ok
          yield Entry.new(entry).freeze
        end
      end

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
    end
  end
end
