#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue GigEthReg
#-----------------------------------------------------------------------------
# File       : GigEthReg.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue GigEthReg
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class GigEthReg(pr.Device):
    def __init__(self, name="GigEthReg", description="GigEthReg", memBase=None, offset=0x0, hidden=False):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################

        for i in range(9):
            self.add(pr.Variable(   name         = "StatusCounters_%i" % (i),
                                    description  = "Status Counters %i" % (i),
                                    offset       =  0x00 + (i * 0x04),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        self.add(pr.Variable(   name         = "StatusVector",
                                description  = "Status Vector",
                                offset       =  0x100,
                                bitSize      =  9,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "PhyStatus",
                                description  = "PhyStatus",
                                offset       =  0x108,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "MacAddress",
                                description  = "MAC Address (big-Endian)",
                                offset       =  0x200,
                                bitSize      =  48,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "PauseTime",
                                description  = "PauseTime",
                                offset       =  0x21C,
                                bitSize      =  16,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "FilterEnable",
                                description  = "FilterEnable",
                                offset       =  0x228,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "PauseEnable",
                                description  = "PauseEnable",
                                offset       =  0x22C,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "RollOverEn",
                                description  = "RollOverEn",
                                offset       =  0xF00,
                                bitSize      =  9,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "CounterReset",
                                description  = "CounterReset",
                                offset       =  0xFF4,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "WO",
                            ))

        self.add(pr.Variable(   name         = "SoftReset",
                                description  = "SoftReset",
                                offset       =  0xFF8,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "WO",
                            ))

        self.add(pr.Variable(   name         = "HardReset",
                                description  = "HardReset",
                                offset       =  0xFFC,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "WO",
                            ))

