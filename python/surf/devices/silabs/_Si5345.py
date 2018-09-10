#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue _Si5345 Module
#-----------------------------------------------------------------------------
# File       : _Si5345.py
# Created    : 2017-01-17
# Last update: 2017-01-17
#-----------------------------------------------------------------------------
# Description:
# PyRogue _Si5345 Module
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the 
# top-level directory of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of 'SLAC Firmware Standard Library', including this file, 
# may be copied, modified, propagated, or distributed except according to 
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import csv

class Si5345(pr.Device):
    def __init__(self,       
            name         = "Si5345",
            description  = "Si5345",
            simpleDisply = True,
            **kwargs):
        super().__init__(name=name, description=description, size=(0x1000<<2), **kwargs)
        
        ##############################
        # 15.1 Page 0 Registers Si5345
        ##############################
                                             
        self.add(pr.RemoteVariable(
            name        = 'PN_BASE_LO',
            description = 'Four-digit base part number, one nibble per digit.',
            offset      = (0x0002 << 2),
            bitSize     = 8,
            mode        = 'RO',
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'PN_BASE_HI',
            description = 'Four-digit base part number, one nibble per digit.',
            offset      = (0x0003 << 2),
            bitSize     = 8,
            mode        = 'RO',
        ))        

        self.add(pr.RemoteVariable(
            name         = 'GRADE', 
            description  = 'One ASCII character indicating the device speed/synthesis mode.',
            offset       = (0x0004 << 2),
            bitSize      = 8, 
            mode         = 'RO',
            enum        = {
                0x0: 'A', 
                0x1: 'B', 
                0x2: 'C', 
                0x3: 'D', 
            },
        ))
        
        self.add(pr.RemoteVariable(
            name         = 'DEVICE_REV', 
            description  = 'One ASCII character indicating the device revision level.',
            offset       = (0x0005 << 2),
            bitSize      = 8, 
            mode         = 'RO',
            enum        = {
                0x0: 'A', 
                0x1: 'B', 
                0x2: 'C', 
                0x3: 'D', 
            },
        ))        
        
        self.add(pr.RemoteVariable(
            name        = 'TOOL_VERSION[0]',
            description = 'The software tool version that creates the register values downloaded at power up is represented by TOOL_VERSION.',
            offset      = (0x0006 << 2),
            bitSize     = 8,
            mode        = 'RW',
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'TOOL_VERSION[1]',
            description = 'The software tool version that creates the register values downloaded at power up is represented by TOOL_VERSION.',
            offset      = (0x0007 << 2),
            bitSize     = 8,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name        = 'TOOL_VERSION[2]',
            description = 'The software tool version that creates the register values downloaded at power up is represented by TOOL_VERSION.',
            offset      = (0x0008 << 2),
            bitSize     = 8,
            mode        = 'RW',
        ))     

        self.add(pr.RemoteVariable(
            name        = 'TEMP_GRADE',
            description = 'Device temperature grading, 0 = Industrial (40 C to 85 C) ambient conditions',
            offset      = (0x0009 << 2),
            bitSize     = 8,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name        = 'PKG_ID',
            description = 'Package ID, 0 = 9x9 mm 64 QFN',
            offset      = (0x000A << 2),
            bitSize     = 8,
            mode        = 'RW',
        ))   

        self.add(pr.RemoteVariable(
            name        = 'I2C_ADDR',
            description = 'The upper five bits of the 7-bit I2C address.',
            offset      = (0x000B << 2),
            bitSize     = 7,
            mode        = 'RO',
        ))           

        self.add(pr.RemoteVariable(
            name        = 'SYSINCAL',
            description = '1 if the device is calibrating.',
            offset      = (0x000C << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOSXAXB',
            description = '1 if there is no signal at the XAXB pins.',
            offset      = (0x000C << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'XAXB_ERR',
            description = '1 if there is a problem locking to the XAXB input signal.',
            offset      = (0x000C << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RO',
        ))   

        self.add(pr.RemoteVariable(
            name        = 'SMBUS_TIMEOUT',
            description = '1 if there is an SMBus timeout error.',
            offset      = (0x000C << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RO',
        ))   

        self.add(pr.RemoteVariable(
            name        = 'LOS',
            description = '1 if the clock input is currently LOS',
            offset      = (0x000D << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RO',
        ))  

        self.add(pr.RemoteVariable(
            name        = 'OOF',
            description = '1 if the clock input is currently OOF',
            offset      = (0x000D << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RO',
        ))   

        self.add(pr.RemoteVariable(
            name        = 'LOL',
            description = '1 if the DSPLL is out of lock',
            offset      = (0x000E << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
        ))   

        self.add(pr.RemoteVariable(
            name        = 'HOLD',
            description = '1 if the DSPLL is in holdover (or free run)',
            offset      = (0x000E << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RO',
        )) 

        self.add(pr.RemoteVariable(
            name        = 'CAL_PLL',
            description = '1 if the DSPLL internal calibration is busy',
            offset      = (0x000F << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RO',
        ))  

        self.add(pr.RemoteVariable(
            name        = 'SYSINCAL_FLG',
            description = 'Sticky version of SYSINCAL. Write a 0 to this bit to clear.',
            offset      = (0x0011 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
        )) 
        
        self.add(pr.RemoteVariable(
            name        = 'LOSXAXB_FLG',
            description = 'Sticky version of LOSXAXB. Write a 0 to this bit to clear.',
            offset      = (0x0011 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name        = 'XAXB_ERR_FLG',
            description = 'Sticky version of XAXB_ERR. Write a 0 to this bit to clear.',
            offset      = (0x0011 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name        = 'SMBUS_TIMEOUT_FLG',
            description = 'Sticky version of SMBUS_TIMEOUT. Write a 0 to this bit to clear.',
            offset      = (0x0011 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
        ))   

        self.add(pr.RemoteVariable(
            name        = 'LOS_FLG',
            description = '1 if the clock input is LOS for the given input',
            offset      = (0x0012 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name        = 'OOF_FLG',
            description = '1 if the clock input is OOF for the given input',
            offset      = (0x0012 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
        ))    

        self.add(pr.RemoteVariable(
            name        = 'LOL_FLG',
            description = '1 if the DSPLL was unlocked',
            offset      = (0x0013 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
        ))    

        self.add(pr.RemoteVariable(
            name        = 'HOLD_FLG',
            description = '1 if the DSPLL was in holdover or free run',
            offset      = (0x0013 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name        = 'CAL_PLL_FLG',
            description = '1 if the internal calibration was busy',
            offset      = (0x0014 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name        = 'LOL_ON_HOLD',
            description = 'Set by CBPro.',
            offset      = (0x0016 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))     

        self.add(pr.RemoteVariable(
            name        = 'SYSINCAL_INTR_MSK',
            description = '1 to mask SYSINCAL_FLG from causing an interrupt',
            offset      = (0x0017 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name        = 'LOSXAXB_INTR_MSK',
            description = '1 to mask the LOSXAXB_FLG from causing an interrupt',
            offset      = (0x0017 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name        = 'SMBUS_TIMEOUT_FLG_MSK',
            description = '1 to mask SMBUS_TIMEOUT_FLG from the interrupt',
            offset      = (0x0017 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name        = 'STATUS_FLG_RESERVED',
            description = 'Factory set to 1 to mask reserved bit from causing an interrupt. Do not clear this bit.',
            offset      = (0x0017 << 2),
            bitSize     = 2,
            bitOffset   = 6,
            mode        = 'WO',
            value        = 0x3,
            hidden       = True,
            verify       = False,            
        ))          

        self.add(pr.RemoteVariable(
            name        = 'LOS_INTR_MSK',
            description = '1 to mask the clock input LOS flag',
            offset      = (0x0018 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        ))   

        self.add(pr.RemoteVariable(
            name        = 'OOF_INTR_MSK',
            description = '1 to mask the clock input OOF flag',
            offset      = (0x0018 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name        = 'LOL_INTR_MSK',
            description = '1 to mask the clock input LOL flag',
            offset      = (0x0019 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name        = 'HOLD_INTR_MSK',
            description = '1 to mask the holdover flag',
            offset      = (0x0019 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CAL_INTR_MSK',
            description = '1 to mask the DSPLL internal calibration busy flag',
            offset      = (0x001A << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
        ))        

        self.add(pr.RemoteCommand(  
            name         = "SOFT_RST_ALL",
            description  = "Initialize and calibrates the entire device",
            offset       = (0x001C << 2),
            bitSize      = 1,
            bitOffset    = 0,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        ))
        
        self.add(pr.RemoteCommand(  
            name         = "SOFT_RST",
            description  = "Initialize outer loop",
            offset       = (0x001C << 2),
            bitSize      = 1,
            bitOffset    = 2,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        )) 

        self.add(pr.RemoteCommand(  
            name         = "FINC",
            description  = "1 a rising edge will cause the selected MultiSynth to increment the output frequency by the Nx_FSTEPW parameter. See registers 0x03390x0358",
            offset       = (0x001D << 2),
            bitSize      = 1,
            bitOffset    = 0,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        ))
        
        self.add(pr.RemoteCommand(  
            name         = "FDEC",
            description  = "1 a rising edge will cause the selected MultiSynth to decrement the output frequency by the Nx_FSTEPW parameter. See registers 0x03390x0358",
            offset       = (0x001D << 2),
            bitSize      = 1,
            bitOffset    = 1,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        ))         

        self.add(pr.RemoteVariable(
            name        = 'PDN',
            description = '1 to put the device into low power mode',
            offset      = (0x001E << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'HARD_RST',
            description = '1 causes hard reset. The same as power up except that the serial port access is not held at reset.',
            offset      = (0x001E << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
        ))        
    
        self.add(pr.RemoteCommand(  
            name         = "SYNC",
            description  = "1 to reset all output R dividers to the same state.",
            offset       = (0x001E << 2),
            bitSize      = 1,
            bitOffset    = 2,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        ))    
    
        self.add(pr.RemoteVariable(
            name        = 'SPI_3WIRE',
            description = '0 for 4-wire SPI, 1 for 3-wire SPI',
            offset      = (0x002B << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RW',
        )) 
        
        self.add(pr.RemoteVariable(
            name        = 'AUTO_NDIV_UPDATE',
            description = 'Set by CBPro.',
            offset      = (0x002B << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))    

        self.add(pr.RemoteVariable(
            name        = 'LOS_EN',
            description = '1 to enable LOS for a clock input',
            offset      = (0x002C << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOSXAXB_DIS',
            description = '0: Enable LOS Detection (default)',
            offset      = (0x002C << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RW',
        ))        

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('LOS_VAL_TIME[%d]' % i), 
                description = ('Clock Input[%d]' % i),
                offset      = (0x002D << 2),
                bitSize     = 2, 
                bitOffset   = (2*i), 
                mode        = 'RW',
                enum        = {
                    0x0: '2ms', 
                    0x1: '100ms', 
                    0x2: '200ms', 
                    0x3: '1000ms', 
                },
            ))
            
        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('LOS_TRG_THR_LO[%d]' % i), 
                description = 'Trigger Threshold 16-bit Threshold Value',
                offset      = ((0x002E+(2*i)) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  
            self.add(pr.RemoteVariable(
                name        = ('LOS_TRG_THR_HI[%d]' % i), 
                description = 'Trigger Threshold 16-bit Threshold Value',
                offset      = ((0x002F+(2*i)) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))   

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('LOS_CLR_THR_LO[%d]' % i), 
                description = 'Clear Threshold 16-bit Threshold Value',
                offset      = ((0x0036+(2*i)) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  
            self.add(pr.RemoteVariable(
                name        = ('LOS_CLR_THR_HI[%d]' % i), 
                description = 'Clear Threshold 16-bit Threshold Value',
                offset      = ((0x0037+(2*i)) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))               

        self.add(pr.RemoteVariable(
            name        = 'OOF_EN',
            description = '1 to enable, 0 to disable',
            offset      = (0x003F << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'FAST_OOF_EN',
            description = '1 to enable, 0 to disable',
            offset      = (0x003F << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
        ))        

        self.add(pr.RemoteVariable(
            name         = 'OOF_REF_SEL', 
            description  = 'OOF Reference Select',
            offset       = (0x0040 << 2),
            bitSize      = 3, 
            mode         = 'RO',
            enum        = {
                0x0: 'CLKIN0', 
                0x1: 'CLKIN1', 
                0x2: 'CLKIN2', 
                0x3: 'CLKIN3', 
                0x4: 'XAXB', 
            },
        ))
        
        for i in range(4):        
            self.add(pr.RemoteVariable(
                name        = ('OOF_DIV_SEL[%d]' % i),
                description = 'Sets a divider for the OOF circuitry for each input clock 0,1,2,3. The divider value is 2OOFx_DIV_SEL. CBPro sets these dividers.',
                offset      = ((0x0041+i) << 2),
                bitSize     = 5,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))         

        self.add(pr.RemoteVariable(
            name        = 'OOFXO_DIV_SEL',
            description = 'Sets a divider for the OOF circuitry for each input clock 0,1,2,3. The divider value is 2OOFx_DIV_SEL. CBPro sets these dividers.',
            offset      = (0x0045 << 2),
            bitSize     = 5,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))         
            
        for i in range(4):        
            self.add(pr.RemoteVariable(
                name        = ('OOF_SET_THR[%d]' % i),
                description = 'OOF Set threshold. Range is up to 500 ppm in steps of 1/16 ppm.',
                offset      = ((0x0046+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))   

        for i in range(4):        
            self.add(pr.RemoteVariable(
                name        = ('OOF_CLR_THR[%d]' % i),
                description = 'OOF Clear threshold. Range is up to 500 ppm in steps of 1/16 ppm.',
                offset      = ((0x004A+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))               
        
        self.add(pr.RemoteVariable(
            name        = 'OOF_DETWIN_SEL[0]',
            description = 'Values calculated by CBPro.',
            offset      = (0x004E << 2),
            bitSize     = 3,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisply,
        )) 

        self.add(pr.RemoteVariable(
            name        = 'OOF_DETWIN_SEL[1]',
            description = 'Values calculated by CBPro.',
            offset      = (0x004E << 2),
            bitSize     = 3,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'OOF_DETWIN_SEL[2]',
            description = 'Values calculated by CBPro.',
            offset      = (0x004F << 2),
            bitSize     = 3,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'OOF_DETWIN_SEL[3]',
            description = 'Values calculated by CBPro.',
            offset      = (0x004F << 2),
            bitSize     = 3,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))      
        
        self.add(pr.RemoteVariable(
            name        = 'OOF_ON_LOS',
            description = 'Values set by CBPro',
            offset      = (0x0050 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))       
        
        for i in range(4):        
            self.add(pr.RemoteVariable(
                name        = ('FAST_OOF_SET_THR[%d]' % i),
                description = '(1+ value) x 1000 ppm',
                offset      = ((0x0051+i) << 2),
                bitSize     = 4,
                mode        = 'RW',
            ))  

        for i in range(4):        
            self.add(pr.RemoteVariable(
                name        = ('FAST_OOF_CLR_THR[%d]' % i),
                description = '(1+ value) x 1000 ppm',
                offset      = ((0x0055+i) << 2),
                bitSize     = 4,
                mode        = 'RW',
            ))              
            
        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('FAST_OOF_DETWIN_SEL[%d]' % i), 
                description = 'Values calculated by CBPro.',
                offset      = (0x0059 << 2),
                bitSize     = 2, 
                bitOffset   = (2*i),   
                mode        = 'RW',
                hidden      = simpleDisply,
            ))           
                
        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('OOF0_RATIO_REF[%d]' % i), 
                description = 'Values calculated by CBPro.',
                offset      = ((0x005A+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('OOF1_RATIO_REF[%d]' % i), 
                description = 'Values calculated by CBPro.',
                offset      = ((0x005E+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('OOF2_RATIO_REF[%d]' % i), 
                description = 'Values calculated by CBPro.',
                offset      = ((0x0062+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('OOF3_RATIO_REF[%d]' % i), 
                description = 'Values calculated by CBPro.',
                offset      = ((0x0066+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))           
            
        self.add(pr.RemoteVariable(
            name        = 'LOL_FST_EN',
            description = 'Enables fast detection of LOL. A large input frequency error will quickly assert LOL when this is enabled.',
            offset      = (0x0092 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name        = 'LOL_FST_DETWIN_SEL',
            description = 'Values calculated by CBPro',
            offset      = (0x0093 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))     

        self.add(pr.RemoteVariable(
            name        = 'LOL_FST_VALWIN_SEL',
            description = 'Values calculated by CBPro',
            offset      = (0x0095 << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))  

        self.add(pr.RemoteVariable(
            name        = 'LOL_FST_SET_THR_SEL',
            description = 'Values calculated by CBPro',
            offset      = (0x0096 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisply,
        )) 

        self.add(pr.RemoteVariable(
            name        = 'LOL_FST_CLR_THR_SEL',
            description = 'Values calculated by CBPro',
            offset      = (0x0098 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisply,
        )) 

        self.add(pr.RemoteVariable(
            name        = 'LOL_SLOW_EN_PLL',
            description = '1 to enable LOL; 0 to disable LOL.',
            offset      = (0x009A << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name        = 'LOL_SLW_DETWIN_SEL',
            description = '1 to enable LOL; 0 to disable LOL.',
            offset      = (0x009B << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name        = 'LOL_SLW_VALWIN_SEL',
            description = 'Values calculated by CBPro.',
            offset      = (0x009D << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))          
        
        self.add(pr.RemoteVariable(
            name        = 'LOL_SLW_SET_THR', 
            description = 'Configures the loss of lock set thresholds',
            offset      = (0x009E << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            enum        = {
                0x0: '0.1 ppm', 
                0x1: '0.3 ppm', 
                0x2: '1 ppm', 
                0x3: '3 ppm', 
                0x4: '10 ppm', 
                0x5: '30 ppm', 
                0x6: '100 ppm', 
                0x7: '300 ppm', 
                0x8: '1000 ppm', 
                0x9: '3000 ppm', 
                0xA: '10000 ppm', 
            },
        )) 

        self.add(pr.RemoteVariable(
            name        = 'LOL_SLW_CLR_THR', 
            description = 'Configures the loss of lock set thresholds.',
            offset      = (0x00A0 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            enum        = {
                0x0: '0.1 ppm', 
                0x1: '0.3 ppm', 
                0x2: '1 ppm', 
                0x3: '3 ppm', 
                0x4: '10 ppm', 
                0x5: '30 ppm', 
                0x6: '100 ppm', 
                0x7: '300 ppm', 
                0x8: '1000 ppm', 
                0x9: '3000 ppm', 
                0xA: '10000 ppm', 
            },
        ))         

        self.add(pr.RemoteVariable(
            name        = 'LOL_TIMER_EN',
            description = '0 to disable, 1 to enable',
            offset      = (0x00A2 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
        ))     

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('LOL_CLR_DELAY_DIV256[%d]' % i), 
                description = 'Set by CBPro.',
                offset      = ((0x00A9+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisply,
            )) 

        self.add(pr.RemoteVariable(
            name        = 'ACTIVE_NVM_BANK', 
            description = 'Read-only field indicating number of user bank writes carried out so far.',
            offset      = (0x00E2 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            enum        = {
                0x00: 'zero', 
                0x03: 'one', 
                0x0F: 'two', 
                0x3F: 'three', 
            },
        ))              

        self.add(pr.RemoteVariable(
            name        = 'NVM_WRITE',
            description = 'Write 0xC7 to initiate an NVM bank burn.',
            offset      = (0x00E3 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
        ))     

        self.add(pr.RemoteCommand(  
            name         = "NVM_READ_BANK",
            description  = "When set, this bit will read the NVM down into the volatile memory.",
            offset       = (0x00E4 << 2),
            bitSize      = 1,
            bitOffset    = 0,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        ))    

        self.add(pr.RemoteVariable(
            name        = 'FASTLOCK_EXTEND_EN',
            description = 'Extend Fastlock bandwidth period past LOL Clear, 0: Do not extend Fastlock period, 1: Extend Fastlock period (default)',
            offset      = (0x00E5 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
        ))           

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('FASTLOCK_EXTEND[%d]' % i), 
                description = 'Set by CBPro.',
                offset      = ((0x00EA+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))

        self.add(pr.RemoteVariable(
            name        = 'REG_0xF7_INTR',
            description = 'Set by CBPro.',
            offset      = (0x00F6 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'REG_0xF8_INTR',
            description = 'Set by CBPro.',
            offset      = (0x00F6 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            hidden      = simpleDisply,
        )) 

        self.add(pr.RemoteVariable(
            name        = 'REG_0xF9_INTR',
            description = 'Set by CBPro.',
            offset      = (0x00F6 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RO',
            hidden      = simpleDisply,
        ))   

        self.add(pr.RemoteVariable(
            name        = 'SYSINCAL_INTR',
            description = 'Set by CBPro.',
            offset      = (0x00F7 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOSXAXB_INTR',
            description = 'Set by CBPro.',
            offset      = (0x00F7 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOSREF_INTR',
            description = 'Set by CBPro.',
            offset      = (0x00F7 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RO',
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOSVCO_INTR',
            description = 'Set by CBPro.',
            offset      = (0x00F7 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RO',
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'SMBUS_TIME_OUT_INTR',
            description = 'Set by CBPro.',
            offset      = (0x00F7 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RO',
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOS_INTR',
            description = 'Set by CBPro.',
            offset      = (0x00F8 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'OOF_INTR',
            description = 'Set by CBPro.',
            offset      = (0x00F8 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RO',
            hidden      = simpleDisply,
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'LOL_INTR',
            description = 'Set by CBPro.',
            offset      = (0x00F9 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'HOLD_INTR',
            description = 'Set by CBPro.',
            offset      = (0x00F9 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RO',
            hidden      = simpleDisply,
        )) 

        self.add(pr.RemoteVariable(
            name        = 'DEVICE_READY',
            description = 'Ready Only byte to indicate device is ready. When read data is 0x0F one can safely read/write registers. This register is repeated on every page therefore a page write is not ever required to read the DEVICE_READY status.',
            offset      = (0x00FE << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
        ))        

        ##############################
        # 15.1 Page 1 Registers Si5345
        ##############################

        self.add(pr.RemoteVariable(
            name        = 'OUTALL_DISABLE_LOW',
            description = '1 Pass through the output enables, 0 disables all output drivers',
            offset      = (0x0102 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
        ))         

        for i in range(10):
            self.add(pr.RemoteVariable(
                name        = ('OUT_PDN[%d]' % i), 
                description = 'Output driver: 0 to power up the regulator, 1 to power down the regulator. Clock outputs will be weakly pulled low.',
                offset      = ( ((0x0108+(5*i)) << 2) if (i!=9) else ((0x0108+(5*i)+5) << 2) ),
                base        = pr.Bool,
                bitSize     = 1,
                bitOffset   = 0,
                mode        = 'RW',
            ))
            
            self.add(pr.RemoteVariable(
                name        = ('OUT_OE[%d]' % i), 
                description = 'Output driver: 0 to disable the output, 1 to enable the output',
                offset      = ( ((0x0108+(5*i)) << 2) if (i!=9) else ((0x0108+(5*i)+5) << 2) ),
                base        = pr.Bool,
                bitSize     = 1,
                bitOffset   = 1,
                mode        = 'RW',
            ))   

            self.add(pr.RemoteVariable(
                name        = ('OUT_RDIV_FORCE2[%d]' % i), 
                description = '0 R0 divider value is set by R0_REG, 1 R0 divider value is forced into divide by 2',
                offset      = ( ((0x0108+(5*i)) << 2) if (i!=9) else ((0x0108+(5*i)+5) << 2) ),
                base        = pr.Bool,
                bitSize     = 1,
                bitOffset   = 2,
                mode        = 'RW',
            ))               

            self.add(pr.RemoteVariable(
                name        = ('OUT_FORMAT[%d]' % i), 
                description = 'OUT_FORMAT',
                offset      = ( ((0x0109+(5*i)) << 2) if (i!=9) else ((0x0109+(5*i)+5) << 2) ),
                bitSize     = 2,
                bitOffset   = 0,
                mode        = 'RW',
                enum        = {
                    0x0: 'Undefined', 
                    0x1: 'swing mode (normal swing) differential', 
                    0x2: 'swing mode (high swing) differential', 
                    0x4: 'LVCMOS single ended', 
                    0x5: 'LVCMOS (+pin only)', 
                    0x6: 'LVCMOS (pin only)', 
                },                
            ))

            self.add(pr.RemoteVariable(
                name        = ('OUT_SYNC_EN[%d]' % i), 
                description = 'enable/disable synchronized (glitchless) operation. When enabled, the power down and output enables are synchronized to the output clock.',
                offset      = ( ((0x0109+(5*i)) << 2) if (i!=9) else ((0x0109+(5*i)+5) << 2) ),
                base        = pr.Bool,
                bitSize     = 1,
                bitOffset   = 3,
                mode        = 'RW',
            ))    

            self.add(pr.RemoteVariable(
                name        = ('OUT_DIS_STATE[%d]' % i), 
                description = 'Determines the state of an output driver when disabled',
                offset      = ( ((0x0109+(5*i)) << 2) if (i!=9) else ((0x0109+(5*i)+5) << 2) ),
                bitSize     = 2,
                bitOffset   = 4,
                mode        = 'RW',
                enum        = {
                    0x0: 'Disable low', 
                    0x1: 'Disable high', 
                },                
            ))
            
            self.add(pr.RemoteVariable(
                name        = ('OUT_CMOS_DRV[%d]' % i), 
                description = 'LVCMOS output impedance.',
                offset      = ( ((0x0109+(5*i)) << 2) if (i!=9) else ((0x0109+(5*i)+5) << 2) ),
                bitSize     = 2,
                bitOffset   = 6,
                mode        = 'RW',
                enum        = {
                    0x0: 'CMOS1', 
                    0x1: 'CMOS2', 
                    0x2: 'CMOS3', 
                },                
            ))

            self.add(pr.RemoteVariable(
                name        = ('OUT_CM[%d]' % i), 
                description = 'This field only applies when OUT0_FORMAT=1 or 2. See Table 6.10 Settings for LVDS, LVPECL, and HCSL on page 41 and 18. Setting the Differential Output Driver to Non-Standard Amplitudes for details of the settings.',
                offset      = ( ((0x010A+(5*i)) << 2) if (i!=9) else ((0x010A+(5*i)+5) << 2) ),
                bitSize     = 4,
                bitOffset   = 0,
                mode        = 'RW',             
            ))

            self.add(pr.RemoteVariable(
                name        = ('OUT_AMPL[%d]' % i), 
                description = 'This field only applies when OUT0_FORMAT=1, 2, or 3. See Table 5.5 Hitless Switching Enable Bit on page 22 and 18. Setting the Differential Output Driver to Non-Standard Amplitudes for details of the settings.',
                offset      = ( ((0x010A+(5*i)) << 2) if (i!=9) else ((0x010A+(5*i)+5) << 2) ),
                bitSize     = 3,
                bitOffset   = 4,
                mode        = 'RW',             
            ))            

            self.add(pr.RemoteVariable(
                name        = ('OUT_MUX_SEL[%d]' % i), 
                description = 'Output driver 0 input mux select.This selects the source of the multisynth',
                offset      = ( ((0x010B+(5*i)) << 2) if (i!=9) else ((0x010B+(5*i)+5) << 2) ),
                bitSize     = 3,
                bitOffset   = 0,
                mode        = 'RW',
                enum        = {
                    0x0: 'N0', 
                    0x1: 'N1', 
                    0x2: 'N2', 
                    0x3: 'N3', 
                    0x4: 'N4', 
                },                
            ))
            
            self.add(pr.RemoteVariable(
                name        = ('OUT_VDD_SEL_EN[%d]' % i), 
                description = '1 = Enable OUT0_VDD_SEL',
                offset      = ( ((0x010B+(5*i)) << 2) if (i!=9) else ((0x010B+(5*i)+5) << 2) ),
                base        = pr.Bool,
                bitSize     = 1,
                bitOffset   = 3,
                mode        = 'RW',               
            ))            

            self.add(pr.RemoteVariable(
                name        = ('OUT_VDD_SEL[%d]' % i), 
                description = 'Must be set to the VDD0 voltage.',
                offset      = ( ((0x010B+(5*i)) << 2) if (i!=9) else ((0x010B+(5*i)+5) << 2) ),
                bitSize     = 2,
                bitOffset   = 4,
                mode        = 'RW',
                enum        = {
                    0x0: '3.3 V', 
                    0x1: '1.8 V', 
                    0x2: '2.5 V', 
                },                
            ))  

            self.add(pr.RemoteVariable(
                name        = ('OUT_INV[%d]' % i), 
                description = 'OUT_INV',
                offset      = ( ((0x010B+(5*i)) << 2) if (i!=9) else ((0x010B+(5*i)+5) << 2) ),
                bitSize     = 2,
                bitOffset   = 6,
                mode        = 'RW',
                enum        = {
                    0x0: 'CLK and CLK not inverted', 
                    0x1: 'CLK inverted', 
                    0x2: 'CLK and CLK inverted', 
                    0x3: 'CLK inverted', 
                },                
            ))              
            
        self.add(pr.RemoteVariable(
            name        = 'OUTX_ALWAYS_ON[0]',
            description = 'This setting is managed by CBPro during zero delay mode.',
            offset      = (0x013F << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))   

        self.add(pr.RemoteVariable(
            name        = 'OUTX_ALWAYS_ON[1]',
            description = 'This setting is managed by CBPro during zero delay mode.',
            offset      = (0x0140 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisply,
        )) 

        self.add(pr.RemoteVariable(
            name        = 'OUT_DIS_MSK',
            description = 'Set by CBPro.',
            offset      = (0x0141 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            hidden      = simpleDisply,
        )) 

        self.add(pr.RemoteVariable(
            name        = 'OUT_DIS_LOL_MSK',
            description = 'Set by CBPro.',
            offset      = (0x0141 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'OUT_DIS_LOSXAXB_MSK',
            description = 'Determines if outputs are disabled during an LOSXAXB condition, 0: All outputs disabled on LOSXAXB, 1: All outputs remain enabled during LOSXAXB condition',
            offset      = (0x0141 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 6,
            mode        = 'RW',
        ))        
            
        self.add(pr.RemoteVariable(
            name        = 'OUT_DIS_MSK_LOS_PFD',
            description = 'Set by CBPro.',
            offset      = (0x0141 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 7,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))    

        self.add(pr.RemoteVariable(
            name        = 'OUT_DIS_MSK_LOL',
            description = '0: LOL will disable all connected outputs, 1: LOL does not disable any outputs',
            offset      = (0x0142 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'OUT_DIS_MSK_HOLD',
            description = 'Set by CBPro.',
            offset      = (0x0142 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'OUT_PDN_ALL',
            description = '0- no effect, 1- all drivers powered down',
            offset      = (0x0145 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
        ))           
            
        ##############################
        # 15.1 Page 2 Registers Si5345
        ##############################
        
        self.add(pr.RemoteVariable(
            name        = 'PXAXB', 
            description = 'Sets the prescale divider for the input clock on XAXB.',
            offset      = (0x0206 << 2),
            bitSize     = 2,
            bitOffset   = 0,
            mode        = 'RO',
            enum        = {
                0x0: 'pre-scale value 1', 
                0x1: 'pre-scale value 2', 
                0x2: 'pre-scale value 4', 
                0x3: 'pre-scale value 8', 
            },
        ))            
            
        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('P0_NUM[%d]' % i), 
                description = 'P0 Divider Numerator',
                offset      = ((0x0208+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('P0_DEN[%d]' % i), 
                description = 'P0 Divider Denominator',
                offset      = ((0x020E+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  
            
        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('P1_NUM[%d]' % i), 
                description = 'P1 Divider Numerator',
                offset      = ((0x0212+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('P1_DEN[%d]' % i), 
                description = 'P1 Divider Denominator',
                offset      = ((0x0218+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            )) 

        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('P2_NUM[%d]' % i), 
                description = 'P2 Divider Numerator',
                offset      = ((0x021C+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('P2_DEN[%d]' % i), 
                description = 'P2 Divider Denominator',
                offset      = ((0x0222+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('P3_NUM[%d]' % i), 
                description = 'P3 Divider Numerator',
                offset      = ((0x0226+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('P3_DEN[%d]' % i), 
                description = 'P3 Divider Denominator',
                offset      = ((0x022C+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))              

        self.add(pr.RemoteVariable(
            name        = 'Px_UPDATE',
            description = '0 - No update for P-divider value, 1 - Update P-divider value',
            offset      = (0x0230 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('P_FRACN_MODE[%d]' % i), 
                description = 'input divider fractional mode. Must be set to 0xB for proper operation.',
                offset      = ((0x0231+i) << 2),
                bitSize     = 4,
                bitOffset   = 0,
                mode        = 'RW',
            ))  

            self.add(pr.RemoteVariable(
                name        = ('P_FRAC_EN[%d]' % i), 
                description = 'input divider fractional enable, 0: Integer-only division, 1: Fractional (or Integer) division',
                offset      = ((0x0231+i) << 2),
                base        = pr.Bool,
            bitSize     = 1,
                bitOffset   = 4,
                mode        = 'RW',
            ))              
            
        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('MXAXB_NUM[%d]' % i), 
                description = 'MXAXB Divider Numerator',
                offset      = ((0x0235+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('MXAXB_DEN[%d]' % i), 
                description = 'MXAXB Divider Denominator',
                offset      = ((0x023B+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))              
            
        self.add(pr.RemoteCommand(  
            name         = "MXAXB_UPDATE",
            description  = "Set to 1 to update the MXAXB_NUM and MXAXB_DEN values. A SOFT_RST may also be used to update these values.",
            offset       = (0x023F << 2),
            bitSize      = 1,
            bitOffset    = 0,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        ))            
            
        for i in range(3):
            self.add(pr.RemoteVariable(
                name        = ('R0_REG[%d]' % i), 
                description = 'R0 Divider: divide value = (REG+1) x 2',
                offset      = ((0x024A+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            )) 

        for i in range(3):
            self.add(pr.RemoteVariable(
                name        = ('R1_REG[%d]' % i), 
                description = 'R1 Divider: divide value = (REG+1) x 2',
                offset      = ((0x024D+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(3):
            self.add(pr.RemoteVariable(
                name        = ('R2_REG[%d]' % i), 
                description = 'R2 Divider: divide value = (REG+1) x 2',
                offset      = ((0x0250+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(3):
            self.add(pr.RemoteVariable(
                name        = ('R3_REG[%d]' % i), 
                description = 'R3 Divider: divide value = (REG+1) x 2',
                offset      = ((0x0256+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(3):
            self.add(pr.RemoteVariable(
                name        = ('R4_REG[%d]' % i), 
                description = 'R4 Divider: divide value = (REG+1) x 2',
                offset      = ((0x0256+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))    

        for i in range(3):
            self.add(pr.RemoteVariable(
                name        = ('R5_REG[%d]' % i), 
                description = 'R5 Divider: divide value = (REG+1) x 2',
                offset      = ((0x0259+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))   

        for i in range(3):
            self.add(pr.RemoteVariable(
                name        = ('R6_REG[%d]' % i), 
                description = 'R6 Divider: divide value = (REG+1) x 2',
                offset      = ((0x025C+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))   

        for i in range(3):
            self.add(pr.RemoteVariable(
                name        = ('R7_REG[%d]' % i), 
                description = 'R7 Divider: divide value = (REG+1) x 2',
                offset      = ((0x025F+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(3):
            self.add(pr.RemoteVariable(
                name        = ('R8_REG[%d]' % i), 
                description = 'R8 Divider: divide value = (REG+1) x 2',
                offset      = ((0x0262+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(3):
            self.add(pr.RemoteVariable(
                name        = ('R9_REG[%d]' % i), 
                description = 'R9 Divider: divide value = (REG+1) x 2',
                offset      = ((0x0268+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(8):
            self.add(pr.RemoteVariable(
                name        = ('DESIGN_ID[%d]' % i), 
                description = 'ASCII encoded string defined by CBPro user',
                offset      = ((0x026B+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))  

        for i in range(8):
            self.add(pr.RemoteVariable(
                name        = ('OPN_ID[%d]' % i), 
                description = 'OPN unique identifier. ASCII encoded by CBPro user',
                offset      = ((0x0278+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))              
            
        self.add(pr.RemoteVariable(
            name        = 'OPN_REVISION',
            description = 'OPN_REVISION',
            offset      = (0x027D << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
        ))   

        self.add(pr.RemoteVariable(
            name        = 'BASELINE_ID',
            description = 'BASELINE_ID',
            offset      = (0x027E << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
        ))           
            
        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('OOF_TRG_THR_EXT[%d]' % i), 
                description = 'Set by CBPro.',
                offset      = ((0x028A+i) << 2),
                bitSize     = 5,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('OOF_CLR_THR_EXT[%d]' % i), 
                description = 'Set by CBPro.',
                offset      = ((0x028E+i) << 2),
                bitSize     = 5,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))           
            
        self.add(pr.RemoteVariable(
            name        = 'FASTLOCK_EXTEND_SCL',
            description = 'Scales LOLB_INT_TIMER_DIV256. Set by CBPro',
            offset      = (0x0294 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOL_SLW_VALWIN_SELX',
            description = 'Set by CBPro.',
            offset      = (0x0296 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name        = 'FASTLOCK_DLY_ONSW_EN',
            description = 'Set by CBPro.',
            offset      = (0x0297 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))   

        self.add(pr.RemoteVariable(
            name        = 'FASTLOCK_DLY_ONLOL_EN',
            description = 'Set by CBPro.',
            offset      = (0x0299 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))       
            
        for i in range(3):
            self.add(pr.RemoteVariable(
                name        = ('FASTLOCK_DLY_ONLOL[%d]' % i), 
                description = 'Set by CBPro.',
                offset      = ((0x029D+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisply,
            )) 

        for i in range(3):
            self.add(pr.RemoteVariable(
                name        = ('FASTLOCK_DLY_ONSW[%d]' % i), 
                description = 'Set by CBPro.',
                offset      = ((0x02A9+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))         
            
        self.add(pr.RemoteVariable(
            name        = 'LOL_NOSIG_TIME',
            description = 'Set by CBPro.',
            offset      = (0x02B7 << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOL_LOS_REFCLK',
            description = 'Set by CBPro.',
            offset      = (0x02B8 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
            hidden      = simpleDisply,
        ))    
            
        ##############################
        # 15.1 Page 3 Registers Si5345
        ##############################
            
        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('N0_NUM[%d]' % i), 
                description = 'N0 Numerator',
                offset      = ((0x0302+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            )) 

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('N0_DEN[%d]' % i), 
                description = 'N0 Denominator',
                offset      = ((0x0308+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))             
            
        self.add(pr.RemoteCommand(  
            name         = "N0_UPDATE",
            description  = "Set this bit to update the N0 divider.",
            offset       = (0x030C << 2),
            bitSize      = 1,
            bitOffset    = 0,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        )) 
        
        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('N1_NUM[%d]' % i), 
                description = 'N1 Numerator',
                offset      = ((0x030D+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            )) 

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('N1_DEN[%d]' % i), 
                description = 'N1 Denominator',
                offset      = ((0x0313+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))             
            
        self.add(pr.RemoteCommand(  
            name         = "N1_UPDATE",
            description  = "Set this bit to update the N1 divider.",
            offset       = (0x0317 << 2),
            bitSize      = 1,
            bitOffset    = 0,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        )) 
        
        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('N2_NUM[%d]' % i), 
                description = 'N2 Numerator',
                offset      = ((0x0318+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            )) 

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('N2_DEN[%d]' % i), 
                description = 'N2 Denominator',
                offset      = ((0x031E+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))             
            
        self.add(pr.RemoteCommand(  
            name         = "N2_UPDATE",
            description  = "Set this bit to update the N2 divider.",
            offset       = (0x0322 << 2),
            bitSize      = 1,
            bitOffset    = 0,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        )) 
        
        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('N3_NUM[%d]' % i), 
                description = 'N3 Numerator',
                offset      = ((0x0323+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            )) 

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('N3_DEN[%d]' % i), 
                description = 'N3 Denominator',
                offset      = ((0x0329+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))             
            
        self.add(pr.RemoteCommand(  
            name         = "N3_UPDATE",
            description  = "Set this bit to update the N3 divider.",
            offset       = (0x032D << 2),
            bitSize      = 1,
            bitOffset    = 0,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        )) 
        
        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('N4_NUM[%d]' % i), 
                description = 'N4 Numerator',
                offset      = ((0x032E+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            )) 

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('N4_DEN[%d]' % i), 
                description = 'N4 Denominator',
                offset      = ((0x0334+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))             
            
        self.add(pr.RemoteCommand(  
            name         = "N4_UPDATE",
            description  = "Set this bit to update the N4 divider.",
            offset       = (0x0338 << 2),
            bitSize      = 1,
            bitOffset    = 0,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        ))  

        self.add(pr.RemoteCommand(  
            name         = "N_UPDATE_ALL",
            description  = "Set this bit to update all five N dividers.",
            offset       = (0x0338 << 2),
            bitSize      = 1,
            bitOffset    = 1,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        ))          
        
        self.add(pr.RemoteVariable(
            name        = 'N_FSTEP_MSK',
            description = '0 to enable FINC/FDEC updates, 1 to disable FINC/FDEC updates',
            offset      = (0x0339 << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RW',
        ))            
        
        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('N0_FSTEPW[%d]' % i), 
                description = 'N0 Frequency Step Word',
                offset      = ((0x033B+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('N1_FSTEPW[%d]' % i), 
                description = 'N1 Frequency Step Word',
                offset      = ((0x0341+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('N2_FSTEPW[%d]' % i), 
                description = 'N2 Frequency Step Word',
                offset      = ((0x0347+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))  

        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('N3_FSTEPW[%d]' % i), 
                description = 'N3 Frequency Step Word',
                offset      = ((0x034D+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            )) 

        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('N4_FSTEPW[%d]' % i), 
                description = 'N4 Frequency Step Word',
                offset      = ((0x0353+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))             
        
        ##############################
        # 15.1 Page 4 Registers Si5345
        ##############################        
        
        self.add(pr.RemoteVariable(
            name        = 'ZDM_EN',
            description = '0 to disable ZD mode, 1 to enable ZD mode',
            offset      = (0x0487 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
        ))        
        
        self.add(pr.RemoteVariable(
            name        = 'ZDM_IN_SEL',
            description = 'Clock input select when in ZD mode. Note: In ZD mode the feedback clock comes into IN3',
            offset      = (0x0487 << 2),
            bitSize     = 2,
            bitOffset   = 1,
            mode        = 'RW',
            enum        = {
                0x0: 'IN0', 
                0x1: 'IN1', 
                0x2: 'IN2', 
            },                
        ))         
        
        self.add(pr.RemoteVariable(
            name        = 'ZDM_AUTOSW_EN',
            description = 'Set by CBPro.',
            offset      = (0x0487 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisply,
        ))
        
        ##############################
        # 15.1 Page 5 Registers Si5345
        ##############################    

        self.add(pr.RemoteVariable(
            name        = 'IN_ACTV',
            description = 'Currently selected DSPLL input clock',
            offset      = (0x0507 << 2),
            bitSize     = 2,
            bitOffset   = 6,
            mode        = 'RO',
            enum        = {
                0x0: 'IN0', 
                0x1: 'IN1', 
                0x2: 'IN2', 
                0x3: 'IN3', 
            },                
        ))          
        
        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('BW_PLL[%d]' % i), 
                description = 'PLL loop bandwidth parameter',
                offset      = ((0x0508+i) << 2),
                bitSize     = 6,
                mode        = 'RW',
            ))   

        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('FAST_LOCK_BW_PLL[%d]' % i), 
                description = 'PLL Fast Lock Loop Bandwidth parameter',
                offset      = ((0x050E+i) << 2),
                bitSize     = 6,
                mode        = 'RW',
            ))                    

        self.add(pr.RemoteCommand(  
            name         = "BW_UPDATE_PLL",
            description  = "Must be set to 1 to update the BWx_PLL and FAST_BWx_PLL parameters",
            offset       = (0x0514 << 2),
            bitSize      = 1,
            bitOffset    = 0,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        ))
                
        for i in range(7):
            self.add(pr.RemoteVariable(
                name        = ('M_NUM[%d]' % i), 
                description = 'M Divider Numerator',
                offset      = ((0x0515+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            )) 

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        = ('M_DEN[%d]' % i), 
                description = 'M Divider Denominator',
                offset      = ((0x051C+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))             
        
        self.add(pr.RemoteCommand(  
            name         = "M_UPDATE",
            description  = "Set this bit to update the M divider.",
            offset       = (0x0520 << 2),
            bitSize      = 1,
            bitOffset    = 0,
            # hidden       = True,
            function     = pr.BaseCommand.toggle,
        ))        
        
        self.add(pr.RemoteVariable(
            name        = 'M_FRAC_MODE',
            description = 'M feedback divider fractional mode, Must be set to 0xB for proper operation',
            offset      = (0x0521 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'WO',
            value        = 0xB,
            hidden       = True,
            verify       = False,                
        ))         

        self.add(pr.RemoteVariable(
            name        = 'M_FRAC_EN',
            description = 'M feedback divider fractional enable: 0: Integer-only division, 1: Fractional (or integer) division - Required for DCO operation.',
            offset      = (0x0521 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RW',              
        )) 
        
        self.add(pr.RemoteVariable(
            name        = 'M_FRAC_RESERVED',
            description = 'Must be set to 1 for DSPLL B',
            offset      = (0x0521 << 2),
            # base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'WO',
            value        = 0x1,
            hidden       = True,
            verify       = False,            
        ))        
        
        self.add(pr.RemoteVariable(
            name        = 'IN_SEL_REGCTRL',
            description = '0 for pin controlled clock selection, 1 for register controlled clock selection',
            offset      = (0x052A << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',               
        ))           
        
        self.add(pr.RemoteVariable(
            name        = 'IN_SEL',
            description = 'Select DSPLL input clock',
            offset      = (0x052A << 2),
            bitSize     = 2,
            bitOffset   = 1,
            mode        = 'RW',
            enum        = {
                0x0: 'IN0', 
                0x1: 'IN1', 
                0x2: 'IN2', 
                0x3: 'IN3', 
            },                
        ))         
        
        self.add(pr.RemoteVariable(
            name        = 'FASTLOCK_AUTO_EN',
            description = 'Applies only when FASTLOCK_MAN = 0 (see below): 0 to disable auto fast lock when the DSPLL is out of lock, 1 to enable auto fast lock',
            offset      = (0x052B << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',               
        ))

        self.add(pr.RemoteVariable(
            name        = 'FASTLOCK_MAN',
            description = '0 for normal operation (see FASTLOCK_AUTO_EN), 1 to force fast lock',
            offset      = (0x052B << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',               
        ))        
                
        self.add(pr.RemoteVariable(
            name        = 'HOLD_EN',
            description = 'Holdover enable: 0: Holdover Disabled, 1: Holdover Enabled (default)',
            offset      = (0x052C << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',               
        )) 

        self.add(pr.RemoteVariable(
            name        = 'HOLD_RAMP_BYP',
            description = 'HOLD_RAMP_BYP',
            offset      = (0x052C << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RW',               
        )) 

        self.add(pr.RemoteVariable(
            name        = 'HOLDEXIT_BW_SEL1',
            description = 'Holdover Exit Bandwidth select',
            offset      = (0x052C << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RW',               
        )) 

        self.add(pr.RemoteVariable(
            name        = 'RAMP_STEP_INTERVAL',
            description = 'Time Interval of the frequency ramp steps when ramping between inputs or when exiting holdover. Calculated by CBPro based on selection.',
            offset      = (0x052C << 2),
            bitSize     = 3,
            bitOffset   = 5,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))      
        
        self.add(pr.RemoteVariable(
            name        = 'HOLD_RAMPBYP_NOHIST',
            description = 'Set by CBPro.',
            offset      = (0x052D << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))   
        
        self.add(pr.RemoteVariable(
            name        = 'HOLD_HIST_LEN',
            description = 'Set by CBPro.',
            offset      = (0x052E << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'HOLD_HIST_DELAY',
            description = 'Set by CBPro.',
            offset      = (0x052F << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'HOLD_REF_COUNT_FRC_PLLB',
            description = 'Set by CBPro.',
            offset      = (0x0531 << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RW',               
            hidden      = simpleDisply,
        )) 
                
        for i in range(3):
            self.add(pr.RemoteVariable(
                name        = ('HOLD_15M_CYC_COUNT_PLLB[%d]' % i), 
                description = 'Value calculated by CBPro',
                offset      = ((0x0532+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))  
        
        self.add(pr.RemoteVariable(
            name        = 'FORCE_HOLD',
            description = '0 for normal operation, 1 for force holdover',
            offset      = (0x0535 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',               
        ))         
        
        self.add(pr.RemoteVariable(
            name        = 'CLK_SWTCH_MODE',
            description = 'Clock switching mode',
            offset      = (0x0536 << 2),
            bitSize     = 2,
            bitOffset   = 0,
            mode        = 'RW',
            enum        = {
                0x0: 'manual', 
                0x1: 'automatic_non-revertive', 
                0x2: 'automatic_revertive', 
            },                
        ))         
        
        self.add(pr.RemoteVariable(
            name        = 'HSW_EN',
            description = '0 glitchless switching mode (phase buildout turned off), 1 hitless switching mode (phase buildout turned on). Note: Hitless switching and zero delay mode are incompatible.',
            offset      = (0x0536 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RW',               
        ))  

        self.add(pr.RemoteVariable(
            name        = 'IN_LOS_MSK',
            description = 'For each clock input LOS alarm: 0 to use LOS in the clock selection logic, 1 to mask LOS from the clock selection logic',
            offset      = (0x0537 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',               
        )) 

        self.add(pr.RemoteVariable(
            name        = 'IN_OOF_MSK',
            description = 'For each clock input OOF alarm: 0 to use OOF in the clock selection logic, 1 to mask OOF from the clock selection logic',
            offset      = (0x0537 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',               
        ))         
        
        self.add(pr.RemoteVariable(
            name        = 'IN_PRIORITY[0]', 
            description = 'priority for clock input',
            offset      = (0x0538 << 2),
            bitSize     = 3,
            bitOffset   = 0,
            mode        = 'RW',
            enum        = {
                0x0: 'no priority', 
                0x1: 'priority 1', 
                0x1: 'priority 2', 
                0x1: 'priority 3', 
                0x1: 'priority 4', 
            },                  
        ))

        self.add(pr.RemoteVariable(
            name        = 'IN_PRIORITY[1]', 
            description = 'priority for clock input',
            offset      = (0x0538 << 2),
            bitSize     = 3,
            bitOffset   = 4,
            mode        = 'RW',
            enum        = {
                0x0: 'no priority', 
                0x1: 'priority 1', 
                0x1: 'priority 2', 
                0x1: 'priority 3', 
                0x1: 'priority 4', 
            },                  
        ))        
           
        self.add(pr.RemoteVariable(
            name        = 'IN_PRIORITY[2]', 
            description = 'priority for clock input',
            offset      = (0x0539 << 2),
            bitSize     = 3,
            bitOffset   = 0,
            mode        = 'RW',
            enum        = {
                0x0: 'no priority', 
                0x1: 'priority 1', 
                0x1: 'priority 2', 
                0x1: 'priority 3', 
                0x1: 'priority 4', 
            },                  
        ))

        self.add(pr.RemoteVariable(
            name        = 'IN_PRIORITY[3]', 
            description = 'priority for clock input',
            offset      = (0x0539 << 2),
            bitSize     = 3,
            bitOffset   = 4,
            mode        = 'RW',
            enum        = {
                0x0: 'no priority', 
                0x1: 'priority 1', 
                0x1: 'priority 2', 
                0x1: 'priority 3', 
                0x1: 'priority 4', 
            },                  
        ))             
                
        self.add(pr.RemoteVariable(
            name        = 'HSW_MODE',
            description = '2: Default setting, do not modify',
            offset      = (0x053A << 2),
            bitSize     = 2,
            bitOffset   = 0,
            mode        = 'WO',
            value        = 0x2,
            hidden       = True,
            verify       = False,                
        ))  

        self.add(pr.RemoteVariable(
            name        = 'HSW_PHMEAS_CTRL',
            description = '0: Default setting, do not modify',
            offset      = (0x053A << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'WO',
            value        = 0x0,
            hidden       = True,
            verify       = False,                
        ))          

        for i in range(2):
            self.add(pr.RemoteVariable(
                name        = ('HSW_PHMEAS_THR[%d]' % i), 
                description = '10-bit value. Set by CBPro.',
                offset      = ((0x053B+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))    
        
        self.add(pr.RemoteVariable(
            name        = 'HSW_COARSE_PM_LEN',
            description = 'Set by CBPro.',
            offset      = (0x053D << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'HSW_COARSE_PM_DLY',
            description = 'Set by CBPro.',
            offset      = (0x053E << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))  

        self.add(pr.RemoteVariable(
            name        = 'HOLD_HIST_VALID',
            description = '1 = there is enough historical frequency data collected for valid holdover',
            offset      = (0x053F << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',               
        ))

        self.add(pr.RemoteVariable(
            name        = 'FASTLOCK_STATUS',
            description = '1 = PLL is in Fast Lock operation',
            offset      = (0x053F << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RO',               
        ))

        self.add(pr.RemoteVariable(
            name        = 'HSW_FINE_PM_LEN',
            description = 'Set by CBPro.',
            offset      = (0x0588 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))

        for i in range(2):
            self.add(pr.RemoteVariable(
                name        = ('PFD_EN_DELAY[%d]' % i), 
                description = 'Set by CBPro.',
                offset      = ((0x0589+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))

        self.add(pr.RemoteVariable(
            name        = 'INIT_LP_CLOSE_HO',
            description = '1: ramp on initial lock, 0: no ramp on initial lock',
            offset      = (0x059B << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',               
        )) 
        
        self.add(pr.RemoteVariable(
            name        = 'HOLD_PRESERVE_HIST',
            description = 'Set by CBPro.',
            offset      = (0x059B << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'HOLD_FRZ_WITH_INTONLY',
            description = 'Set by CBPro.',
            offset      = (0x059B << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'HOLD_EXIT_BW_SEL0',
            description = 'Set by CBPro.',
            offset      = (0x059B << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 6,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))

        self.add(pr.RemoteVariable(
            name        = 'HOLD_EXIT_STD_BO',
            description = 'Set by CBPro.',
            offset      = (0x059B << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 7,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))

        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = ('HOLDEXIT_BW[%d]' % i), 
                description = 'Set by CBPro.',
                offset      = ((0x059D+i) << 2),
                bitSize     = 6,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))     
      
        self.add(pr.RemoteVariable(
            name        = 'RAMP_STEP_SIZE',
            description = 'Set by CBPro.',
            offset      = (0x05A6 << 2),
            bitSize     = 3,
            bitOffset   = 0,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'RAMP_SWITCH_EN',
            description = 'Ramp Switching Enable: 0: Disable Ramp Switching, 1: Enable Ramp Switching (default)',
            offset      = (0x05A6 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RW',               
        ))  

        ##############################
        # 15.1 Page 9 Registers Si5345
        ##############################

        self.add(pr.RemoteVariable(
            name        = 'XAXB_EXTCLK_EN',
            description = '0 to use a crystal at the XAXB pins, 1 to use an external clock source at the XAXB pins',
            offset      = (0x090E << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',               
        ))  
        
        self.add(pr.RemoteVariable(
            name        = 'IO_VDD_SEL',
            description = '0 for 1.8 V external connections, 1 for 3.3 V external connections',
            offset      = (0x0943 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',               
        )) 

        self.add(pr.RemoteVariable(
            name        = 'IN_EN',
            description = '0: Disable and Powerdown Input Buffer, 1: Enable Input Buffer for IN3IN0.',
            offset      = (0x0949 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',               
        ))  

        self.add(pr.RemoteVariable(
            name        = 'IN_PULSED_CMOS_EN',
            description = '0: Standard Input Format, 1: Pulsed CMOS Input Format for IN3IN0',
            offset      = (0x0949 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',               
        ))          

        self.add(pr.RemoteVariable(
            name        = 'INX_TO_PFD_EN',
            description = 'Value calculated in CBPro',
            offset      = (0x094A << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))

        for i in range(2):
            self.add(pr.RemoteVariable(
                name        = ('REFCLK_HYS_SEL[%d]' % i), 
                description = 'Value calculated in CBPro',
                offset      = ((0x094E+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))

        self.add(pr.RemoteVariable(
            name        = 'MXAXB_INTEGER',
            description = 'Set by CBPro.',
            offset      = (0x095E << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))

        ##############################
        # 15.1 Page A Registers Si5345
        ##############################

        self.add(pr.RemoteVariable(
            name        = 'N_ADD_0P5',
            description = 'Value calculated in CBPro.',
            offset      = (0x0A02 << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RW',               
            hidden      = simpleDisply,
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'N_CLK_TO_OUTX_EN',
            description = 'Routes Multisynth outputs to output driver muxes.',
            offset      = (0x0A03 << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RW',               
        )) 

        self.add(pr.RemoteVariable(
            name        = 'N_PIBYP',
            description = 'Output Multisynth integer divide mode: 0: Nx divider is fractional, 1: Nx divider is integer',
            offset      = (0x0A04 << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RW',               
        ))  

        self.add(pr.RemoteVariable(
            name        = 'N_PDNB',
            description = 'Powers down the N dividers, Set to 0 to power down unused N dividers, Must set to 1 for all active N dividers',
            offset      = (0x0A05 << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RW',               
        ))          

        for i in range(5):
            self.add(pr.RemoteVariable(
                name        = ('N_HIGH_FREQ[%d]' % i), 
                description = 'Set by CBPro.',
                offset      = ((0x0A14+i) << 2),
                bitSize     = 3,
                mode        = 'RW',
                hidden      = simpleDisply,
            ))

        ##############################
        # 15.1 Page B Registers Si5345
        ##############################        
        
        
        self.add(pr.RemoteVariable(
            name        = 'PDIV_FRACN_CLK_DIS_PLL',
            description = 'Disable digital clocks to input P (IN03) fractional dividers.',
            offset      = (0x0B44 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',               
        ))   

        self.add(pr.RemoteVariable(
            name        = 'FRACN_CLK_DIS_PLL',
            description = 'Disable digital clock to M fractional divider.',
            offset      = (0x0B44 << 2),
            base        = pr.Bool,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',               
        ))   

        self.add(pr.RemoteVariable(
            name        = 'LOS_CLK_DIS',
            description = 'Set to 0 for normal operation.',
            offset      = (0x0B46 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',               
        ))    

        self.add(pr.RemoteVariable(
            name        = 'OOF_CLK_DIS',
            description = 'Set to 0 for normal operation.',
            offset      = (0x0B47 << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RW',               
        ))   

        self.add(pr.RemoteVariable(
            name        = 'OOF_DIV_CLK_DIS',
            description = 'Set to 0 for normal operation.',
            offset      = (0x0B48 << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RW',               
        ))   

        self.add(pr.RemoteVariable(
            name        = 'N_CLK_DIS',
            description = 'Disable digital clocks to N dividers. Must be set to 0 to use each N divider. See also related registers 0x0A03 and 0x0A05.',
            offset      = (0x0B4A << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RW',               
        ))           
        
        for i in range(2):
            self.add(pr.RemoteVariable(
                name        = ('VCO_RESET_CALCODE[%d]' % i), 
                description = '12-bit value. Controls the VCO frequency when a reset occurs.',
                offset      = ((0x0B57+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
            ))          

        ##############################
        # Commands
        ##############################           
        @self.command(value='',description="Load the .CSV from CBPro.",)
        def LoadCsvFile(arg):
            # Check if non-empty argument 
            if (arg != ""):
                path = arg
            else:
                # Use the variable path instead
                path = self.CsvFilePath.get()            
                
            # Open the .CSV file
            with open(path) as csvfile:
                reader = csv.reader(csvfile, delimiter=',', quoting=csv.QUOTE_NONE) 
                # Loop through the rows in the CSV file
                for row in reader:     
                    self._rawWrite(
                        offset = (row['Address']<<2),
                        data   = row['Data'],
                    )                
