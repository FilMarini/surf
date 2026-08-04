-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Provenance : HAND-WRITTEN integration bridge (not BSV-derived). Supersedes
--              the old style/examples/RoceConfigurator.vhd mechanism (single
--              303/276-bit register + edge-detected go bit) with per-field
--              32-bit registers and a GO-strobe / BUSY / DONE protocol.
-- Struct refs: src-bsv/MetaData.bsv (MetaDataReq/Resp:661-671, ReqPD/RespPD:
--              253-263, ReqMR/RespMR:163-177), src-bsv/Controller.bsv
--              (ReqQP/RespQP:60-76), src-bsv/DataTypes.bsv (AttrQP:423-450,
--              QpCapacity:415-421, QpInitAttr:452-455).
-------------------------------------------------------------------------------
-- Register map (32-bit registers; each BSV struct field at bit 0 of its own
-- word; 64-bit laddr spans two consecutive words LO/HI). RW unless (RO).
--
--   0x000 CONTROL   [0] GO (self-clearing strobe)  [2:1] REQ_TYPE (00 PD,
--                   01 MR, 10 QP)
--   0x004 STATUS    (RO) [0] DONE  [1] BUSY  [2] ERR (sticky; GO while BUSY)
--                   [4:3] RESP_TAG  [5] RESP_SUCCESS
--   0x008 VERSION   (RO) [7:0] bridge version  [15:8] MAX_QP_G
--   0x00C SCRATCH   RW scratchpad
--   --- PD request bank (ReqPD) ---
--   0x100 PD_CTRL       [0] allocOrNot
--   0x104 PD_KEY        [30:0]
--   0x108 PD_HANDLER    [31:0]                      (for dealloc)
--   --- MR request bank (ReqMR) ---
--   0x200 MR_CTRL       [0] allocOrNot  [1] lkeyOrNot
--   0x204 MR_LADDR_LO   [31:0]   0x208 MR_LADDR_HI [63:32]
--   0x20C MR_LEN        [31:0]
--   0x210 MR_ACC_FLAGS  [7:0]
--   0x214 MR_PD_HANDLER [31:0]
--   0x218 MR_LKEY_PART  [24:0]
--   0x21C MR_RKEY_PART  [24:0]
--   0x220 MR_LKEY       [31:0]   0x224 MR_RKEY [31:0]  (for dereg)
--   --- QP request bank (ReqQP, full AttrQP coverage) ---
--   0x300 QP_CTRL       [1:0] reqType (00 CREATE, 01 DESTROY, 10 MODIFY,
--                       11 QUERY)  [5:2] qpState  [8:6] pmtu  [12:9] qpType
--                       [13] sqSigAll
--   0x304 QP_PD_HANDLER [31:0]
--   0x308 QP_QPN        [23:0]
--   0x30C QP_ATTR_MASK  [25:0]
--   0x310 QP_QKEY       [31:0]
--   0x314 QP_RQ_PSN     [23:0]   0x318 QP_SQ_PSN [23:0]
--   0x31C QP_DQPN       [23:0]
--   0x320 QP_ACCESS_FLAGS [7:0]
--   0x324 QP_PKEY_INDEX [15:0]
--   0x328 QP_MAX_RD_ATOMIC [7:0]   0x32C QP_MAX_DEST_RD_ATOMIC [7:0]
--   0x330 QP_MIN_RNR_TIMER [4:0]   0x334 QP_TIMEOUT   [4:0]
--   0x338 QP_RETRY_CNT     [2:0]   0x33C QP_RNR_RETRY [2:0]
--   0x340 QP_CUR_STATE     [3:0]
--   0x344 QP_MAX_SEND_WR   [7:0]   0x348 QP_MAX_RECV_WR   [7:0]
--   0x34C QP_MAX_SEND_SGE  [7:0]   0x350 QP_MAX_RECV_SGE  [7:0]
--   0x354 QP_MAX_INLINE_DATA [7:0]
--   0x358 QP_SQ_DRAINING   [0]
--   0x360..0x36C QP_DGID   [127:0], little-word order (DGID0 is [31:0])
--   0x370 QP_TRAFFIC_CLASS [7:0]   0x374 QP_HOP_LIMIT [7:0]
--   0x378 QP_SGID_INDEX    [7:0]
--   --- Response bank (RO; captured on completion) ---
--   0x400 RESP_STATUS     [0] success  [2:1] tag
--   0x404 RESP_PD_HANDLER [31:0]
--   0x408 RESP_PD_KEY     [30:0]
--   0x40C RESP_MR_LKEY    [31:0]   0x410 RESP_MR_RKEY [31:0]
--   0x414 RESP_QP_QPN     [23:0]
--   0x418..0x424 RESP_QP_DGID [127:0]
--   0x428 RESP_QP_PATH [7:0] trafficClass [15:8] hopLimit
--                       [23:16] sgidIndex [24] overrideValid
--
-- Protocol: program the bank for REQ_TYPE, write CONTROL with GO=1 (single
-- write; GO self-clears). BUSY rises until the response is captured; DONE
-- then rises (cleared on the next accepted GO) and mdDoneIrq pulses one
-- cycle. GO while BUSY is ignored and sets the sticky ERR bit. The MemRegion
-- / qpAttr echo portions of RespMR/RespQP are intentionally not exposed (the
-- driver wrote them); RESP_* covers the allocated handles/keys/qpn + success.
-- VERSION 2 adds the RoCEv2 path bank.  The original 303/276-bit generated
-- metadata ABI remains unchanged; this bridge validates INIT-to-RTR before
-- forwarding it and maintains the distinct per-QP path schema used only by
-- the RoCE TX sideband.  Invalid/non-IPv4-mapped DGIDs are completed locally
-- with success=0, so the generated QP controller never sees the transition.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use work.RocePkg.all;

entity RoceMetaDataAxil is
   generic (
      TPD_G          : time            := 1 ns;
      RST_POLARITY_G : sl              := '1';  -- '1' active HIGH reset, '0' active LOW
      RST_ASYNC_G    : boolean         := false;
      MAX_QP_G       : positive        := 4;    -- reported in VERSION only
      VERSION_G      : slv(7 downto 0) := x"02");
   port (
      clk             : in  sl;
      rst             : in  sl := not RST_POLARITY_G;
      -- AXI-Lite slave (register access)
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- MetaData server pair (to TransportLayer mdSrv*)
      mdSrvReqValid   : out sl;
      mdSrvReqData    : out slv(ROCE_MD_REQ_W_C-1 downto 0);
      mdSrvReqReady   : in  sl;
      mdSrvRespValid  : in  sl;
      mdSrvRespData   : in  slv(ROCE_MD_RESP_W_C-1 downto 0);
      mdSrvRespReady  : out sl;
      -- Per-QP packet-local path context, packed as MAX_QP_G consecutive
      -- ROCE_TX_PATH_META_W_C-bit entries (QP 0 in the least-significant
      -- slice).  Consumed only by the RoCE TX wrapper.
      qpPathMeta      : out slv(MAX_QP_G*ROCE_TX_PATH_META_W_C-1 downto 0);
      -- completion interrupt (1-cycle pulse when DONE sets)
      mdDoneIrq       : out sl);
end entity RoceMetaDataAxil;

architecture rtl of RoceMetaDataAxil is

   type PathMetaArray is array (natural range <>) of
      slv(ROCE_TX_PATH_META_W_C-1 downto 0);
   type PathDgidArray is array (natural range <>) of slv(127 downto 0);

   constant VERSION_C : slv(31 downto 0) :=
      x"0000" & toSlv(MAX_QP_G, 8) & VERSION_G;

   type StateType is (
      IDLE_S,
      SEND_S,
      WAIT_RESP_S);

   type RegType is record
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      state          : StateType;
      -- control/status
      reqType        : slv(1 downto 0);
      scratch        : slv(31 downto 0);
      done           : sl;
      err            : sl;
      irq            : sl;
      -- PD request bank
      pdAlloc        : sl;
      pdKey          : slv(30 downto 0);
      pdHandler      : slv(31 downto 0);
      -- MR request bank
      mrAlloc        : sl;
      mrLkeyOrNot    : sl;
      mrLaddr        : slv(63 downto 0);
      mrLen          : slv(31 downto 0);
      mrAccFlags     : slv(7 downto 0);
      mrPdHandler    : slv(31 downto 0);
      mrLkeyPart     : slv(24 downto 0);
      mrRkeyPart     : slv(24 downto 0);
      mrLkey         : slv(31 downto 0);
      mrRkey         : slv(31 downto 0);
      -- QP request bank (full ReqQP coverage)
      qpReqType      : slv(1 downto 0);
      qpState        : slv(3 downto 0);
      qpCurState     : slv(3 downto 0);
      qpPmtu         : slv(2 downto 0);
      qpType         : slv(3 downto 0);
      qpSqSigAll     : sl;
      qpPdHandler    : slv(31 downto 0);
      qpQpn          : slv(23 downto 0);
      qpAttrMask     : slv(25 downto 0);
      qpQkey         : slv(31 downto 0);
      qpRqPsn        : slv(23 downto 0);
      qpSqPsn        : slv(23 downto 0);
      qpDqpn         : slv(23 downto 0);
      qpAccessFlags  : slv(7 downto 0);
      qpPkeyIndex    : slv(15 downto 0);
      qpMaxRdAtomic  : slv(7 downto 0);
      qpMaxDestRdAtomic : slv(7 downto 0);
      qpMinRnrTimer  : slv(4 downto 0);
      qpTimeout      : slv(4 downto 0);
      qpRetryCnt     : slv(2 downto 0);
      qpRnrRetry     : slv(2 downto 0);
      qpMaxSendWr    : slv(7 downto 0);
      qpMaxRecvWr    : slv(7 downto 0);
      qpMaxSendSge   : slv(7 downto 0);
      qpMaxRecvSge   : slv(7 downto 0);
      qpMaxInlineData : slv(7 downto 0);
      qpSqDraining   : sl;
      qpDgid         : slv(127 downto 0);
      qpTrafficClass : slv(7 downto 0);
      qpHopLimit     : slv(7 downto 0);
      qpSgidIndex    : slv(7 downto 0);
      pathMeta       : PathMetaArray(MAX_QP_G-1 downto 0);
      pathDgid       : PathDgidArray(MAX_QP_G-1 downto 0);
      issuedQpn      : slv(23 downto 0);
      issuedReqType  : slv(1 downto 0);
      issuedDgid     : slv(127 downto 0);
      issuedPathMeta : slv(ROCE_TX_PATH_META_W_C-1 downto 0);
      issuedPathUpdate : sl;
      -- response bank (RO)
      respTag        : slv(1 downto 0);
      respSuccess    : sl;
      respPdHandler  : slv(31 downto 0);
      respPdKey      : slv(30 downto 0);
      respMrLkey     : slv(31 downto 0);
      respMrRkey     : slv(31 downto 0);
      respQpQpn      : slv(23 downto 0);
      respQpDgid     : slv(127 downto 0);
      respQpPath     : slv(31 downto 0);
      -- mdSrv request face (registered)
      mdReqValid     : sl;
      mdReqData      : slv(ROCE_MD_REQ_W_C-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      state          => IDLE_S,
      reqType        => (others => '0'),
      scratch        => (others => '0'),
      done           => '0',
      err            => '0',
      irq            => '0',
      pdAlloc        => '0',
      pdKey          => (others => '0'),
      pdHandler      => (others => '0'),
      mrAlloc        => '0',
      mrLkeyOrNot    => '0',
      mrLaddr        => (others => '0'),
      mrLen          => (others => '0'),
      mrAccFlags     => (others => '0'),
      mrPdHandler    => (others => '0'),
      mrLkeyPart     => (others => '0'),
      mrRkeyPart     => (others => '0'),
      mrLkey         => (others => '0'),
      mrRkey         => (others => '0'),
      qpReqType      => (others => '0'),
      qpState        => (others => '0'),
      qpCurState     => (others => '0'),
      qpPmtu         => (others => '0'),
      qpType         => (others => '0'),
      qpSqSigAll     => '0',
      qpPdHandler    => (others => '0'),
      qpQpn          => (others => '0'),
      qpAttrMask     => (others => '0'),
      qpQkey         => (others => '0'),
      qpRqPsn        => (others => '0'),
      qpSqPsn        => (others => '0'),
      qpDqpn         => (others => '0'),
      qpAccessFlags  => (others => '0'),
      qpPkeyIndex    => (others => '0'),
      qpMaxRdAtomic  => (others => '0'),
      qpMaxDestRdAtomic => (others => '0'),
      qpMinRnrTimer  => (others => '0'),
      qpTimeout      => (others => '0'),
      qpRetryCnt     => (others => '0'),
      qpRnrRetry     => (others => '0'),
      qpMaxSendWr    => (others => '0'),
      qpMaxRecvWr    => (others => '0'),
      qpMaxSendSge   => (others => '0'),
      qpMaxRecvSge   => (others => '0'),
      qpMaxInlineData => (others => '0'),
      qpSqDraining   => '0',
      qpDgid         => (others => '0'),
      qpTrafficClass => (others => '0'),
      qpHopLimit     => x"20",
      qpSgidIndex    => (others => '0'),
      pathMeta       => (others => (others => '0')),
      pathDgid       => (others => (others => '0')),
      issuedQpn      => (others => '0'),
      issuedReqType  => (others => '0'),
      issuedDgid     => (others => '0'),
      issuedPathMeta => (others => '0'),
      issuedPathUpdate => '0',
      respTag        => (others => '0'),
      respSuccess    => '0',
      respPdHandler  => (others => '0'),
      respPdKey      => (others => '0'),
      respMrLkey     => (others => '0'),
      respMrRkey     => (others => '0'),
      respQpQpn      => (others => '0'),
      respQpDgid     => (others => '0'),
      respQpPath     => (others => '0'),
      mdReqValid     => '0',
      mdReqData      => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axilReadMaster, axilWriteMaster, mdSrvReqReady,
                   mdSrvRespData, mdSrvRespValid, r, rst) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
      variable go     : sl;
      variable busy   : sl;
      variable pathMetaV : slv(ROCE_TX_PATH_META_W_C-1 downto 0);
      variable pathValid : sl;
      variable qpIdx     : natural range 0 to MAX_QP_G-1;
   begin
      v := r;

      -- self-clearing strobes
      go    := '0';
      v.irq := '0';
      pathValid := '1';

      busy := toSl(r.state /= IDLE_S);

      ------------------------------------------------------------------------
      -- AXI-Lite register decode
      ------------------------------------------------------------------------
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster,
                      v.axilWriteSlave, v.axilReadSlave);

      -- control / status
      axiSlaveRegister (axilEp, x"000", 0, go);
      axiSlaveRegister (axilEp, x"000", 1, v.reqType);
      axiSlaveRegisterR(axilEp, x"004", 0, r.done);
      axiSlaveRegisterR(axilEp, x"004", 1, busy);
      axiSlaveRegisterR(axilEp, x"004", 2, r.err);
      axiSlaveRegisterR(axilEp, x"004", 3, r.respTag);
      axiSlaveRegisterR(axilEp, x"004", 5, r.respSuccess);
      axiSlaveRegisterR(axilEp, x"008", 0, VERSION_C);
      axiSlaveRegister (axilEp, x"00C", 0, v.scratch);
      -- PD request bank
      axiSlaveRegister (axilEp, x"100", 0, v.pdAlloc);
      axiSlaveRegister (axilEp, x"104", 0, v.pdKey);
      axiSlaveRegister (axilEp, x"108", 0, v.pdHandler);
      -- MR request bank
      axiSlaveRegister (axilEp, x"200", 0, v.mrAlloc);
      axiSlaveRegister (axilEp, x"200", 1, v.mrLkeyOrNot);
      axiSlaveRegister (axilEp, x"204", 0, v.mrLaddr);       -- spans 0x204/0x208
      axiSlaveRegister (axilEp, x"20C", 0, v.mrLen);
      axiSlaveRegister (axilEp, x"210", 0, v.mrAccFlags);
      axiSlaveRegister (axilEp, x"214", 0, v.mrPdHandler);
      axiSlaveRegister (axilEp, x"218", 0, v.mrLkeyPart);
      axiSlaveRegister (axilEp, x"21C", 0, v.mrRkeyPart);
      axiSlaveRegister (axilEp, x"220", 0, v.mrLkey);
      axiSlaveRegister (axilEp, x"224", 0, v.mrRkey);
      -- QP request bank
      axiSlaveRegister (axilEp, x"300", 0, v.qpReqType);
      axiSlaveRegister (axilEp, x"300", 2, v.qpState);
      axiSlaveRegister (axilEp, x"300", 6, v.qpPmtu);
      axiSlaveRegister (axilEp, x"300", 9, v.qpType);
      axiSlaveRegister (axilEp, x"300", 13, v.qpSqSigAll);
      axiSlaveRegister (axilEp, x"304", 0, v.qpPdHandler);
      axiSlaveRegister (axilEp, x"308", 0, v.qpQpn);
      axiSlaveRegister (axilEp, x"30C", 0, v.qpAttrMask);
      axiSlaveRegister (axilEp, x"310", 0, v.qpQkey);
      axiSlaveRegister (axilEp, x"314", 0, v.qpRqPsn);
      axiSlaveRegister (axilEp, x"318", 0, v.qpSqPsn);
      axiSlaveRegister (axilEp, x"31C", 0, v.qpDqpn);
      axiSlaveRegister (axilEp, x"320", 0, v.qpAccessFlags);
      axiSlaveRegister (axilEp, x"324", 0, v.qpPkeyIndex);
      axiSlaveRegister (axilEp, x"328", 0, v.qpMaxRdAtomic);
      axiSlaveRegister (axilEp, x"32C", 0, v.qpMaxDestRdAtomic);
      axiSlaveRegister (axilEp, x"330", 0, v.qpMinRnrTimer);
      axiSlaveRegister (axilEp, x"334", 0, v.qpTimeout);
      axiSlaveRegister (axilEp, x"338", 0, v.qpRetryCnt);
      axiSlaveRegister (axilEp, x"33C", 0, v.qpRnrRetry);
      axiSlaveRegister (axilEp, x"340", 0, v.qpCurState);
      axiSlaveRegister (axilEp, x"344", 0, v.qpMaxSendWr);
      axiSlaveRegister (axilEp, x"348", 0, v.qpMaxRecvWr);
      axiSlaveRegister (axilEp, x"34C", 0, v.qpMaxSendSge);
      axiSlaveRegister (axilEp, x"350", 0, v.qpMaxRecvSge);
      axiSlaveRegister (axilEp, x"354", 0, v.qpMaxInlineData);
      axiSlaveRegister (axilEp, x"358", 0, v.qpSqDraining);
      axiSlaveRegister (axilEp, x"360", 0, v.qpDgid);
      axiSlaveRegister (axilEp, x"370", 0, v.qpTrafficClass);
      axiSlaveRegister (axilEp, x"374", 0, v.qpHopLimit);
      axiSlaveRegister (axilEp, x"378", 0, v.qpSgidIndex);
      -- response bank (RO)
      axiSlaveRegisterR(axilEp, x"400", 0, r.respSuccess);
      axiSlaveRegisterR(axilEp, x"400", 1, r.respTag);
      axiSlaveRegisterR(axilEp, x"404", 0, r.respPdHandler);
      axiSlaveRegisterR(axilEp, x"408", 0, r.respPdKey);
      axiSlaveRegisterR(axilEp, x"40C", 0, r.respMrLkey);
      axiSlaveRegisterR(axilEp, x"410", 0, r.respMrRkey);
      axiSlaveRegisterR(axilEp, x"414", 0, r.respQpQpn);
      axiSlaveRegisterR(axilEp, x"418", 0, r.respQpDgid);
      axiSlaveRegisterR(axilEp, x"428", 0, r.respQpPath);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      ------------------------------------------------------------------------
      -- Request/response FSM (one MetaDataReq in flight at a time)
      ------------------------------------------------------------------------
      case r.state is
         ---------------------------------------------------------------------
         when IDLE_S =>
            if (go = '1') then
               v.done := '0';
               v.err  := '0';
               -- pack MetaDataReq = tag & member (member LSB-justified in the
               -- 301-bit union payload, deriving(Bits) first-field-at-MSB)
               v.mdReqData := (others => '0');
               case v.reqType is        -- v: honor a REQ_TYPE written with GO
                  when ROCE_MD_TAG_MR_C =>
                     v.mdReqData := ROCE_MD_TAG_MR_C & toSlv(0, 49) &
                                    r.mrAlloc &
                                    r.mrLaddr & r.mrLen & r.mrAccFlags &
                                    r.mrPdHandler & r.mrLkeyPart & r.mrRkeyPart &
                                    r.mrLkeyOrNot & r.mrLkey & r.mrRkey;
                  when ROCE_MD_TAG_QP_C =>
                     pathValid := toSl(r.qpDgid(127 downto 32) =
                                      x"00000000000000000000FFFF" and
                                      r.qpDgid(31 downto 0) /= x"00000000");
                     pathMetaV := (others => '0');
                     pathMetaV(31 downto 0)  := r.qpDgid(31 downto 0);
                     pathMetaV(39 downto 32) := r.qpTrafficClass;
                     pathMetaV(47 downto 40) := r.qpHopLimit;
                     pathMetaV(55 downto 48) := r.qpSgidIndex;
                     pathMetaV(56)           := pathValid;
                     v.issuedQpn              := r.qpQpn;
                     v.issuedReqType          := r.qpReqType;
                     v.issuedDgid             := r.qpDgid;
                     v.issuedPathMeta         := pathMetaV;
                     v.issuedPathUpdate       := toSl(r.qpReqType = "10" and
                                                       r.qpState = x"2");
                     -- INIT -> RTR is rejected locally for an absent, zero,
                     -- or native-IPv6 DGID.  The core request is not issued,
                     -- therefore the QP state cannot advance on failure.
                     if (v.issuedPathUpdate = '1') and (pathValid = '0') then
                        v.respTag     := ROCE_MD_TAG_QP_C;
                        v.respSuccess := '0';
                        v.respQpQpn   := r.qpQpn;
                        v.done        := '1';
                        v.irq         := '1';
                        v.mdReqValid  := '0';
                        v.state       := IDLE_S;
                     else
                        v.mdReqData := ROCE_MD_TAG_QP_C &
                                    r.qpReqType & r.qpPdHandler & r.qpQpn &
                                    r.qpAttrMask &
                                    r.qpState & r.qpCurState & r.qpPmtu &
                                    r.qpQkey & r.qpRqPsn & r.qpSqPsn & r.qpDqpn &
                                    r.qpAccessFlags &
                                    r.qpMaxSendWr & r.qpMaxRecvWr &
                                    r.qpMaxSendSge & r.qpMaxRecvSge &
                                    r.qpMaxInlineData &
                                    r.qpPkeyIndex & r.qpSqDraining &
                                    r.qpMaxRdAtomic & r.qpMaxDestRdAtomic &
                                    r.qpMinRnrTimer & r.qpTimeout &
                                    r.qpRetryCnt & r.qpRnrRetry &
                                    r.qpType & r.qpSqSigAll;
                     end if;
                  when others =>        -- ROCE_MD_TAG_PD_C
                     v.mdReqData := ROCE_MD_TAG_PD_C & toSlv(0, 237) &
                                    r.pdAlloc & r.pdKey & r.pdHandler;
               end case;
               if not (v.reqType = ROCE_MD_TAG_QP_C and
                       v.issuedPathUpdate = '1' and pathValid = '0') then
                  v.mdReqValid := '1';
                  v.state      := SEND_S;
               end if;
            end if;
         ---------------------------------------------------------------------
         when SEND_S =>
            if (go = '1') then
               v.err := '1';            -- GO while BUSY: ignored, sticky ERR
            end if;
            if (mdSrvReqReady = '1') then
               v.mdReqValid := '0';
               v.state      := WAIT_RESP_S;
            end if;
         ---------------------------------------------------------------------
         when WAIT_RESP_S =>
            if (go = '1') then
               v.err := '1';            -- GO while BUSY: ignored, sticky ERR
            end if;
            if (mdSrvRespValid = '1') then
               -- demux MetaDataResp by tag (RespPD/RespMR/RespQP layouts)
               v.respTag := mdSrvRespData(275 downto 274);
               case mdSrvRespData(275 downto 274) is
                  when ROCE_MD_TAG_MR_C =>
                     v.respSuccess := mdSrvRespData(250);
                     v.respMrLkey  := mdSrvRespData(63 downto 32);
                     v.respMrRkey  := mdSrvRespData(31 downto 0);
                  when ROCE_MD_TAG_QP_C =>
                     v.respSuccess := mdSrvRespData(273);
                     v.respQpQpn   := mdSrvRespData(272 downto 249);
                     qpIdx := 0;
                     if MAX_QP_G > 1 then
                        qpIdx := to_integer(unsigned(r.issuedQpn(23 downto
                                  24-log2(MAX_QP_G))));
                     end if;
                     if (mdSrvRespData(273) = '1') and
                        (r.issuedPathUpdate = '1') then
                        v.pathMeta(qpIdx) := r.issuedPathMeta;
                        v.pathDgid(qpIdx) := r.issuedDgid;
                     elsif (mdSrvRespData(273) = '1') and
                           (r.issuedReqType = "01") then
                        v.pathMeta(qpIdx) := (others => '0');
                        v.pathDgid(qpIdx) := (others => '0');
                     end if;
                     if r.issuedReqType = "11" then
                        v.respQpDgid := r.pathDgid(qpIdx);
                        pathMetaV := r.pathMeta(qpIdx);
                     else
                        v.respQpDgid := r.issuedDgid;
                        pathMetaV := r.issuedPathMeta;
                     end if;
                     v.respQpPath := (others => '0');
                     v.respQpPath(7 downto 0)   := pathMetaV(39 downto 32);
                     v.respQpPath(15 downto 8)  := pathMetaV(47 downto 40);
                     v.respQpPath(23 downto 16) := pathMetaV(55 downto 48);
                     v.respQpPath(24)           := pathMetaV(56);
                  when others =>        -- ROCE_MD_TAG_PD_C
                     v.respSuccess   := mdSrvRespData(63);
                     v.respPdHandler := mdSrvRespData(62 downto 31);
                     v.respPdKey     := mdSrvRespData(30 downto 0);
               end case;
               v.done  := '1';
               v.irq   := '1';
               v.state := IDLE_S;
            end if;
      end case;

      -- synchronous reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      mdSrvReqValid  <= r.mdReqValid;
      mdSrvReqData   <= r.mdReqData;
      -- FWFT pop: hold ready while waiting; the one response beat pops on the
      -- edge where valid and ready are both high
      mdSrvRespReady <= toSl(r.state = WAIT_RESP_S);
      mdDoneIrq      <= r.irq;
      for i in 0 to MAX_QP_G-1 loop
         qpPathMeta((i+1)*ROCE_TX_PATH_META_W_C-1 downto
                    i*ROCE_TX_PATH_META_W_C) <= r.pathMeta(i);
      end loop;
   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
