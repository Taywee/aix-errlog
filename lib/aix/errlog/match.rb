require 'date'

require 'aix/errlog/constants'
require 'aix/errlog/lib'

module AIX
  module Errlog
    ##
    # A class that is useful for building errlog matchers.
    #
    # You usually won't need to access this class directly; you'll be able to
    # create instances of it indirectly through the field accessors that are
    # available in Errlog.
    #
    # You can build field matchers using the methods on the errlog and standard
    # logical operators, and there are standard conversions for certain things
    # like Time and DateTime operations.  For instance, if you wanted errlog
    # entries only in January 2018 with +FOO+ in the label somewhere, you cold
    # use a match like this with an Errlog instance.
    #
    #   (
    #     (errlog.match_timestamp >= DateTime.new(2018, 1, 1)) &
    #     (errlog.match_timestamp < DateTime.new(2018, 2, 1)) &
    #     errlog.match_label.include?('FOO')
    #   )
    #
    # It really is that easy.  The rest of the magic is done for you behind the
    # scenes, as long as you follow the rules and know how to make these matches
    # in the C equivalent.  Note that there must always be a Match on the left
    # side of all comparisons, so something like 
    #
    #   DateTime.new(2018, 1, 1) <= errlog.match_timestamp
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
          raise "left should be either a Match or Symbol object, but is #{@left}"
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
          raise "left should be either a Match or Symbol object, but is #{@left}"
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
    end
  end
end
