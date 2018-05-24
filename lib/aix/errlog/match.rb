require 'date'

require 'aix/errlog/constants'
require 'aix/errlog/lib'

module AIX
  module Errlog
    ##
    # A class that is useful for building errlog matchers.
    #
    # You usually won't need to access this class directly; you'll be able to
    # create instances of it indirectly through the use of Errlog::match
    #
    # You can build field matchers using the methods on the errlog and standard
    # logical operators, and there are standard conversions for certain things
    # like Time and DateTime operations.  For instance, if you wanted errlog
    # entries only in January 2018 with +FOO+ in the label somewhere, you cold
    # use a match like this with an Errlog instance.
    #
    #   errlog.match {
    #     (timestamp >= DateTime.new(2018, 1, 1)) &
    #     (timestamp < DateTime.new(2018, 2, 1)) &
    #     label.include?('FOO')
    #   }
    #
    # It really is that easy.  The rest of the magic is done for you behind the
    # scenes, as long as you follow the rules and know how to make these matches
    # in the C equivalent.  Note that there must always be a Match on the left
    # side of all comparisons, so something like 
    #
    #   DateTime.new(2018, 1, 1) <= errlog.match{timestamp}
    #
    # is not possible.
    # 
    # This class should allow you to build matches for errlog_find_first in a
    # simple and natural way.  Note that & is the +LE_OP_AND+ operator, and | is
    # the +LE_OP_OR+ operator, not &&, +and+, ||, or +or+, because those can't
    # be overridden.
    class Match
      attr_accessor :left, :operator, :right

      def initialize(left:, operator: nil, right: nil)
        @left = left
        @operator = operator
        @right = right
      end

      # Uses the structure of this object to build a errlog_match_t structure.
      # Does not check whether operators only work on leaves or any other
      # specifics as that (for instance, an and operator needs two Match leaves,
      # and won't work between a field and a Match or anything like that).  The
      # function itself might check some of the operators to make sure that
      # they're set and throw an error for you, but something like a segfault is
      # more likely if you screw up the structure.  Make sure you know what
      # you're doing.
      def to_struct
        raise "operator must be a symbol, but is #{@operator}" unless @operator.is_a? Symbol

        # We want to be sure the struct is not garbage collected before it's
        # used, so we need to retain a reference to it that ensures that it will
        # live as long as this object
        @struct = Lib::ErrlogMatch.new

        @struct[:em_op] = @operator

        case @left
        when Match
          @struct[:emu1][:emu_left] = @left.to_struct
        when Symbol
          @struct[:emu1][:emu_field] = @left
        else
          raise "left should be either a Match or Symbol object, but is a #{@left.class}"
        end

        case @right
        when Match
          @struct[:emu2][:emu_right] = @right.to_struct
        when String
          @struct[:emu2][:emu_strvalue] = @right
        when Numeric, Time
          @struct[:emu2][:emu_intvalue] = @right.to_i
        when DateTime
          @struct[:emu2][:emu_intvalue] = @right.to_time.to_i
        else
          raise "Right should be either a Match, String, Numeric, Time, or DateTime object, but is a #{@right.class}"
        end

        @struct
      end

      def ==(other)
        @operator = :equal
        @right = other
        self
      end
      def !=(other)
        @operator = :ne
        @right = other
        self
      end
      def include?(other)
        @operator = :substr
        @right = other
        self
      end
      def <(other)
        @operator = :lt
        @right = other
        self
      end
      def <=(other)
        @operator = :le
        @right = other
        self
      end
      def >(other)
        @operator = :gt
        @right = other
        self
      end
      def >=(other)
        @operator = :ge
        @right = other
        self
      end
      def &(other)
        Match.new(
          left: self,
          operator: :and,
          right: other,
        )
      end
      def |(other)
        Match.new(
          left: self,
          operator: :or,
          right: other,
        )
      end
      def ^(other)
        Match.new(
          left: self,
          operator: :xor,
          right: other,
        )
      end
      def !
        Match.new(
          left: self,
          operator: :not,
        )
      end

      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # sequence.
      def self.sequence
        new(left: :sequence)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # label.
      def self.label
        new(left: :label)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # timestamp.
      def self.timestamp
        new(left: :timestamp)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # crcid.
      def self.crcid
        new(left: :crcid)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # machineid.
      def self.machineid
        new(left: :machineid)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # nodeid.
      def self.nodeid
        new(left: :nodeid)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # class.
      def self.class
        new(left: :class)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # type.
      def self.type
        new(left: :type)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # resource.
      def self.resource
        new(left: :resource)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # rclass.
      def self.rclass
        new(left: :rclass)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # rtype.
      def self.rtype
        new(left: :rtype)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # vpd_ibm.
      def self.vpd_ibm
        new(left: :vpd_ibm)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # vpd_user.
      def self.vpd_user
        new(left: :vpd_user)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against in.
      def self.in
        new(left: :in)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # connwhere.
      def self.connwhere
        new(left: :connwhere)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # flag_err64.
      def self.flag_err64
        new(left: :flag_err64)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # flag_errdup.
      def self.flag_errdup
        new(left: :flag_errdup)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # detail_data.
      def self.detail_data
        new(left: :detail_data)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # symptom_data.
      def self.symptom_data
        new(left: :symptom_data)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # errdiag.
      def self.errdiag
        new(left: :errdiag)
      end
      ##
      # Match convenience function.  Gets a Leaf match for comparing against
      # wparid.
      def self.wparid
        new(left: :wparid)
      end
    end
  end
end
