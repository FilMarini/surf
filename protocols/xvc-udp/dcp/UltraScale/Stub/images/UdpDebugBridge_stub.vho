U_Core: entity work.UdpDebugBridge
  port map (
    axisClk => axisClk,
    axisRst => axisRst,
    \mAxisReq[tValid]\ => mAxisReq.tValid,
    \mAxisReq[tData]\ => mAxisReq.tData,
    \mAxisReq[tStrb]\ => mAxisReq.tStrb,
    \mAxisReq[tKeep]\ => mAxisReq.tKeep,
    \mAxisReq[tLast]\ => mAxisReq.tLast,
    \mAxisReq[tDest]\ => mAxisReq.tDest,
    \mAxisReq[tId]\ => mAxisReq.tId,
    \mAxisReq[tUser]\ => mAxisReq.tUser,
    \sAxisReq[tReady]\ => sAxisReq.tReady,
    \mAxisTdo[tValid]\ => mAxisTdo.tValid,
    \mAxisTdo[tData]\ => mAxisTdo.tData,
    \mAxisTdo[tStrb]\ => mAxisTdo.tStrb,
    \mAxisTdo[tKeep]\ => mAxisTdo.tKeep,
    \mAxisTdo[tLast]\ => mAxisTdo.tLast,
    \mAxisTdo[tDest]\ => mAxisTdo.tDest,
    \mAxisTdo[tId]\ => mAxisTdo.tId,
    \mAxisTdo[tUser]\ => mAxisTdo.tUser,
    \sAxisTdo[tReady]\ => sAxisTdo.tReady);
