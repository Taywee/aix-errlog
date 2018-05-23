module AIX
  module Errlog
    module Errors
      class ErrlogError < StandardError
      end
      class InvalidArgument < ErrlogError
        def initialize(message)
          super "A parameter error was detected.  Detail: #{message}"
        end
      end
      class NoFile < ErrlogError
        def initialize(message)
          super "The log file does not exist.  Detail: #{message}"
        end
      end
      class NoMem < ErrlogError
        def initialize(message)
          super "Memory could not be allocated.  Detail: #{message}"
        end
      end
      class IO < ErrlogError
        def initialize(message)
          super "An i/o error occurred.  Detail: #{message}"
        end
      end
      class InvalidFile < ErrlogError
        def initialize(message)
          super "The file is not a valid error log.  Detail: #{message}"
        end
      end
      class UnknownError < ErrlogError
        def initialize(message)
          super "An error occured that could not be diagnosed.  Detail: #{message}"
        end
      end
      LOOKUP = {
        invarg: InvalidArgument,
        nofile: NoFile,
        nomem: NoMem,
        io: IO,
        invfile: InvalidFile,
      }
      def self.throw(status, detail)
        errorClass = LOOKUP[status] || UnknownError
        raise errorClass, detail
      end
    end
  end
end
