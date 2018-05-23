require 'ffi'

require 'aix/errlog/constants'

module AIX
  module Errlog
    ## 
    # The ffi interface to the errlog library.
    #
    # You should never need to access this directly.  All necessary functionality
    # should be accessible via AIX::Errlog
    module Lib
      extend FFI::Library
      ffi_lib 'liberrlog.a(shr_64.o)'

      typedef :pointer, :errlog_handle_t
      typedef :pointer, :errlog_handle_t_ptr
      typedef :pointer, :errlog_match_t_ptr
      typedef :pointer, :errlog_entry_t_ptr

      Err = enum(
        :ok, 0,
        :invarg, Constants::LE_ERR_INVARG,
        :nofile, Constants::LE_ERR_NOFILE,
        :invfile, Constants::LE_ERR_INVFILE,
        :nomem, Constants::LE_ERR_NOMEM,
        :nowrite, Constants::LE_ERR_NOWRITE,
        :io, Constants::LE_ERR_IO,
        :done, Constants::LE_ERR_DONE,
      )

      Direction = enum(
        :forward, Constants::LE_FORWARD,
        :reverse, Constants::LE_REVERSE,
      )

      class Errdup < FFI::Struct
        layout(
          :ed_dupcount, :uint,
          :ed_time1, :uint32,
          :ed_time2, :uint32,
        )
      end

      class ErrlogEntry < FFI::Struct
        layout(
          :el_magic, :uint,
          :el_sequence, :uint,
          :el_label, [:char, Constants::LE_LABEL_MAX],
          :el_timestamp, :uint,
          :el_crcid, :uint,
          :el_errdiag, :uint,
          :el_machineid, [:char, Constants::LE_MACHINE_ID_MAX],
          :el_nodeid, [:char, Constants::LE_NODE_ID_MAX],
          :el_class, [:char, Constants::LE_CLASS_MAX],
          :el_type, [:char, Constants::LE_TYPE_MAX],
          :el_resource, [:char, Constants::LE_RESOURCE_MAX],
          :el_rclass, [:char, Constants::LE_RCLASS_MAX],
          :el_rtype, [:char, Constants::LE_RTYPE_MAX],
          :el_vpd_ibm, [:char, Constants::LE_VPD_MAX],
          :el_vpd_user, [:char, Constants::LE_VPD_MAX],
          :el_in, [:char, Constants::LE_IN_MAX],
          :el_connwhere, [:char, Constants::LE_CONN_MAX],
          :el_flags, :ushort,
          :el_detail_length, :ushort,
          :el_detail_data, [:char, Constants::LE_DETAIL_MAX],
          :el_symptom_length, :uint,
          :el_symptom_data, [:char, Constants::LE_SYMPTOM_MAX],
          :el_errdup, Errdup,
          :el_wparid, [:char, Constants::LE_WPAR_ID_MAX],
        )
      end

      class ErrlogMatch1U < FFI::Union
        layout(
          :emu_left, :pointer,
          :emu_field, :uint,
        )
      end

      class ErrlogMatch2U < FFI::Union
        layout(
          :emu_right, :pointer,
          :emu_intvalue, :uint,
          :emu_strvalue, :string,
        )
      end

      class ErrlogMatch < FFI::Struct
        layout(
          :em_op, :uint,
          :emu1, ErrlogMatch1U,
          :emu2, ErrlogMatch2U,
        )
      end

      attach_function :errlog_open, [
        :string, # path
        :int, # mode
        :uint, # magic
        :errlog_handle_t_ptr, # handle
      ], Err

      attach_function :errlog_close, [
        :errlog_handle_t, # handle
      ], Err

      attach_function :errlog_find_first, [
        :errlog_handle_t, # handle
        :errlog_match_t_ptr, # filter
        :errlog_entry_t_ptr, # result
      ], Err

      attach_function :errlog_find_next, [
        :errlog_handle_t, # handle
        :errlog_entry_t_ptr, # result
      ], Err

      attach_function :errlog_find_sequence, [
        :errlog_handle_t, # handle
        :int, # sequence
        :errlog_entry_t_ptr, # result
      ], Err

      attach_function :errlog_set_direction, [
        :errlog_handle_t, # handle
        Direction, # direction
      ], Err
    end
  end
end
