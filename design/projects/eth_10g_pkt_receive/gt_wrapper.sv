`resetall
`default_nettype none
`timescale 1ns / 1ps

module gt_wrapper (
        input  wire             i_refclk,
        input  wire             i_rx_usrclk,
        input  wire             i_rx_usrclk2,
        output wire             o_rxout_clk,
        
        input  wire             i_lpm_reset,
        input  wire             i_gtx_rx_reset,
        input  wire             i_gtx_tx_reset,

        input  wire             i_rx_p,
        input  wire             i_rx_n,
        
        input  wire             i_rxslip,
                
        input  wire             i_rx_polarity,
        
        output wire [31:0]      o_rxdata,
        output wire             o_rxdatavaild,
        output wire [1:0]       o_rxheader,
        output wire             o_rxheader_valid,
        output wire             o_rxstartofseq,
        output wire [2:0]       o_rx_status,
        output wire             o_rx_reset_done
    );
        
    localparam logic [2:0] CPLLREFCLKSEL = 3'b001;
    
    //These are for 64B/67B, rather than 64B/66B
    logic rxheader_unused;

    //Using 32b data rather than 64b
    logic [31:0] rxdata_unused; 
    
    //------------------------- GT Instantiations  --------------------------
        GTXE2_CHANNEL #
        (
            //_______________________ Simulation-Only Attributes __________________
    
            .SIM_RECEIVER_DETECT_PASS   ("TRUE"),
            .SIM_TX_EIDLE_DRIVE_LEVEL   ("X"),
            .SIM_RESET_SPEEDUP          ("FALSE"),
            .SIM_CPLLREFCLK_SEL         (CPLLREFCLKSEL),
            .SIM_VERSION                ("4.0"),
            

           //----------------RX Byte and Word Alignment Attributes---------------
        
                // We don't use comma alignment
            
           //----------------RX 8B/10B Decoder Attributes---------------
                
                // We don't use 8B/10B

           //----------------------RX Clock Correction Attributes----------------------
           
            /*
            .CBCC_DATA_SOURCE_SEL                   ("ENCODED"),
            .CLK_COR_SEQ_2_USE                      ("FALSE"),
            .CLK_COR_KEEP_IDLE                      ("FALSE"),
            .CLK_COR_MAX_LAT                        (19),
            .CLK_COR_MIN_LAT                        (15),
            .CLK_COR_PRECEDENCE                     ("TRUE"),
            .CLK_COR_REPEAT_WAIT                    (0),
            .CLK_COR_SEQ_LEN                        (1),
            .CLK_COR_SEQ_1_ENABLE                   (4'b1111),
            .CLK_COR_SEQ_1_1                        (10'b0100000000),
            .CLK_COR_SEQ_1_2                        (10'b0000000000),
            .CLK_COR_SEQ_1_3                        (10'b0000000000),
            .CLK_COR_SEQ_1_4                        (10'b0000000000),
            .CLK_CORRECT_USE                        ("FALSE"),
            .CLK_COR_SEQ_2_ENABLE                   (4'b1111),
            .CLK_COR_SEQ_2_1                        (10'b0100000000),
            .CLK_COR_SEQ_2_2                        (10'b0000000000),
            .CLK_COR_SEQ_2_3                        (10'b0000000000),
            .CLK_COR_SEQ_2_4                        (10'b0000000000),
            */

           //----------------------RX Channel Bonding Attributes----------------------
            
            /*
            .CHAN_BOND_KEEP_ALIGN                   ("FALSE"),
            .CHAN_BOND_MAX_SKEW                     (1),
            .CHAN_BOND_SEQ_LEN                      (1),
            .CHAN_BOND_SEQ_1_1                      (10'b0000000000),
            .CHAN_BOND_SEQ_1_2                      (10'b0000000000),
            .CHAN_BOND_SEQ_1_3                      (10'b0000000000),
            .CHAN_BOND_SEQ_1_4                      (10'b0000000000),
            .CHAN_BOND_SEQ_1_ENABLE                 (4'b1111),
            .CHAN_BOND_SEQ_2_1                      (10'b0000000000),
            .CHAN_BOND_SEQ_2_2                      (10'b0000000000),
            .CHAN_BOND_SEQ_2_3                      (10'b0000000000),
            .CHAN_BOND_SEQ_2_4                      (10'b0000000000),
            .CHAN_BOND_SEQ_2_ENABLE                 (4'b1111),
            .CHAN_BOND_SEQ_2_USE                    ("FALSE"),
            .FTS_DESKEW_SEQ_ENABLE                  (4'b1111),
            .FTS_LANE_DESKEW_CFG                    (4'b1111),
            .FTS_LANE_DESKEW_EN                     ("FALSE"),
            */

           //-------------------------RX Margin Analysis Attributes----------------------------
            .ES_CONTROL                             (6'b000000),
            .ES_ERRDET_EN                           ("FALSE"),
            .ES_EYE_SCAN_EN                         ("FALSE"),
            .ES_HORZ_OFFSET                         (12'h000),
            .ES_PMA_CFG                             (10'b0000000000),
            .ES_PRESCALE                            (5'b00000),
            .ES_QUALIFIER                           (80'h00000000000000000000),
            .ES_QUAL_MASK                           (80'h00000000000000000000),
            .ES_SDATA_MASK                          (80'h00000000000000000000),
            .ES_VERT_OFFSET                         (9'b000000000),

           //-----------------------FPGA RX Interface Attributes-------------------------
            .RX_DATA_WIDTH                          (32),

           //-------------------------PMA Attributes----------------------------
            .OUTREFCLK_SEL_INV                      (2'b11),
            .PMA_RSV                                (32'h001E_7080),
            .PMA_RSV2                               (16'h2050),
            .PMA_RSV3                               (2'b00),
            .PMA_RSV4                               (32'h00000000),
            .RX_BIAS_CFG                            (12'b000000000100),
            //P96 says to set to 008101 not A00?
            .DMONITOR_CFG                           (24'h000A00),
            .RX_CM_SEL                              (2'b11),        
            .RX_CM_TRIM                             (3'b010),           //Along with PMA_RSV2[4] (== 1), sets voltage to 800MV common mode
            .RX_DEBUG_CFG                           (12'b000000000000),
            .RX_OS_CFG                              (13'b0000010000000),
            .TERM_RCAL_CFG                          (5'b10000),
            .TERM_RCAL_OVRD                         (1'b0),
            .TST_RSV                                (32'h00000000),
            .RX_CLK25_DIV                           (13),
            .TX_CLK25_DIV                           (13),
            .UCODEER_CLR                            (1'b0),

           //-------------------------PCI Express Attributes----------------------------
            .PCS_PCIE_EN                            ("FALSE"),

           //-------------------------PCS Attributes----------------------------
            .PCS_RSVD_ATTR                          (3'b100),

           //-----------RX Buffer Attributes------------
            .RXBUF_EN                               ("FALSE"),

           //---------------------CDR Attributes-------------------------

           //For SATA Gen1 GTP- set RXCDR_CFG=83'h0_0000_47FE_1060_2448_1010
            .RXCDR_CFG                              (72'h0b000023ff10400020),
            .RXCDR_FR_RESET_ON_EIDLE                (1'b0),
            .RXCDR_HOLD_DURING_EIDLE                (1'b0),
            .RXCDR_PH_RESET_ON_EIDLE                (1'b0),
            .RXCDR_LOCK_CFG                         (6'b010101),

           //-----------------RX Initialization and Reset Attributes-------------------
            .RXCDRFREQRESET_TIME                    (5'b00001),
            .RXCDRPHRESET_TIME                      (5'b00001),
            .RXISCANRESET_TIME                      (5'b00001),
            .RXPCSRESET_TIME                        (5'b00001),
            .RXPMARESET_TIME                        (5'b00011),

           //-----------------RX OOB Signaling Attributes-------------------
            .RXOOB_CFG                              (7'b0000110),

           //-----------------------RX Gearbox Attributes---------------------------
            .RXGEARBOX_EN                           ("TRUE"),
            .GEARBOX_MODE                           (3'b001),

           //-----------------------PRBS Detection Attribute-----------------------
            .RXPRBS_ERR_LOOPBACK                    (1'b0),

           //-----------Power-Down Attributes----------
            .PD_TRANS_TIME_FROM_P2                  (12'h03c),
            .PD_TRANS_TIME_NONE_P2                  (8'h19),
            .PD_TRANS_TIME_TO_P2                    (8'h64),

           //-----------RX OOB Signaling Attributes----------
            .SAS_MAX_COM                            (64),
            .SAS_MIN_COM                            (36),
            .SATA_BURST_SEQ_LEN                     (4'b0101),
            .SATA_BURST_VAL                         (3'b100),
            .SATA_EIDLE_VAL                         (3'b100),
            .SATA_MAX_BURST                         (8),
            .SATA_MAX_INIT                          (21),
            .SATA_MAX_WAKE                          (7),
            .SATA_MIN_BURST                         (4),
            .SATA_MIN_INIT                          (12),
            .SATA_MIN_WAKE                          (4),

           //-----------RX Fabric Clock Output Control Attributes----------
            .TRANS_TIME_RATE                        (8'h0E),

           //------------TX Buffer Attributes----------------
            .TXBUF_EN                               ("FALSE"),
            .TXBUF_RESET_ON_RATE_CHANGE             ("TRUE"),
            .TXDLY_CFG                              (16'h001F),
            .TXDLY_LCFG                             (9'h030),
            .TXDLY_TAP_CFG                          (16'h0000),
            .TXPH_CFG                               (16'h0780),
            .TXPHDLY_CFG                            (24'h084020),
            .TXPH_MONITOR_SEL                       (5'b00000),
            .TX_XCLK_SEL                            ("TXUSR"),

           //-----------------------FPGA TX Interface Attributes-------------------------
            .TX_DATA_WIDTH                          (32),

           //-----------------------TX Configurable Driver Attributes-------------------------
            .TX_DEEMPH0                             (5'b00000),
            .TX_DEEMPH1                             (5'b00000),
            .TX_EIDLE_ASSERT_DELAY                  (3'b110),
            .TX_EIDLE_DEASSERT_DELAY                (3'b100),
            .TX_LOOPBACK_DRIVE_HIZ                  ("FALSE"),
            .TX_MAINCURSOR_SEL                      (1'b1),
            .TX_DRIVE_MODE                          ("DIRECT"),
            .TX_MARGIN_FULL_0                       (7'b1001110),
            .TX_MARGIN_FULL_1                       (7'b1001001),
            .TX_MARGIN_FULL_2                       (7'b1000101),
            .TX_MARGIN_FULL_3                       (7'b1000010),
            .TX_MARGIN_FULL_4                       (7'b1000000),
            .TX_MARGIN_LOW_0                        (7'b1000110),
            .TX_MARGIN_LOW_1                        (7'b1000100),
            .TX_MARGIN_LOW_2                        (7'b1000010),
            .TX_MARGIN_LOW_3                        (7'b1000000),
            .TX_MARGIN_LOW_4                        (7'b1000000),

           //-----------------------TX Gearbox Attributes--------------------------
            .TXGEARBOX_EN                           ("TRUE"),

           //-----------------------TX Initialization and Reset Attributes--------------------------
            .TXPCSRESET_TIME                        (5'b00001),
            .TXPMARESET_TIME                        (5'b00001),

           //-----------------------TX Receiver Detection Attributes--------------------------
            .TX_RXDETECT_CFG                        (14'h1832),
            .TX_RXDETECT_REF                        (3'b100),

           //--------------------------CPLL Attributes----------------------------
            .CPLL_CFG                               (24'hBC07DC),
            .CPLL_FBDIV                             (4),
            .CPLL_FBDIV_45                          (5),
            .CPLL_INIT_CFG                          (24'h00001E),
            .CPLL_LOCK_CFG                          (16'h01E8),
            .CPLL_REFCLK_DIV                        (1),
            .RXOUT_DIV                              (1),
            .TXOUT_DIV                              (1),
            .SATA_CPLL_CFG                          ("VCO_3000MHZ"),

           //------------RX Initialization and Reset Attributes-------------
            .RXDFELPMRESET_TIME                     (7'b0001111),

           //------------RX Equalizer Attributes-------------
            .RXLPM_HF_CFG                           (14'b00000011110000),
            .RXLPM_LF_CFG                           (14'b00000011110000),
            .RX_DFE_GAIN_CFG                        (23'h020FEA),
            .RX_DFE_H2_CFG                          (12'b000000000000),
            .RX_DFE_H3_CFG                          (12'b000001000000),
            .RX_DFE_H4_CFG                          (11'b00011110000),
            .RX_DFE_H5_CFG                          (11'b00011100000),
            .RX_DFE_KL_CFG                          (13'b0000011111110),
            .RX_DFE_LPM_CFG                         (16'h0104),
            .RX_DFE_LPM_HOLD_DURING_EIDLE           (1'b0),
            .RX_DFE_UT_CFG                          (17'b10001111000000000),
            .RX_DFE_VP_CFG                          (17'b00011111100000011),

           //-----------------------Power-Down Attributes-------------------------
            .RX_CLKMUX_PD                           (1'b1),
            .TX_CLKMUX_PD                           (1'b1),

           //-----------------------FPGA RX Interface Attribute-------------------------
            .RX_INT_DATAWIDTH                       (1),

           //-----------------------FPGA TX Interface Attribute-------------------------
            .TX_INT_DATAWIDTH                       (1),

           //----------------TX Configurable Driver Attributes---------------
            .TX_QPI_STATUS_EN                       (1'b0),

           //-----------------------RX Equalizer Attributes--------------------------
            .RX_DFE_KL_CFG2                         (13'b0000000000000),
            .RX_DFE_XYD_CFG                         (13'b0000000000000),

           //-----------------------TX Configurable Driver Attributes--------------------------
            .TX_PREDRIVER_MODE                      (1'b0)

            
        ) 
        gtxe2_i 
        (
        
        //------------------------------- CPLL Ports -------------------------------
        .CPLLFBCLKLOST                  (/* Unused */),
        .CPLLLOCK                       (/* Unused */),
        .CPLLLOCKDETCLK                 (1'b0),
        .CPLLLOCKEN                     (1'b1),
        .CPLLPD                         (1'b1),
        .CPLLREFCLKLOST                 (/* Unused */),
        .CPLLREFCLKSEL                  (1'b001), //Selecting GTREFCLK0 to go into CPLL
        .CPLLRESET                      (1'b0),
        .GTRSVD                         (16'b0000000000000000),
        .PCSRSVDIN                      (16'b0000000000000000),
        .PCSRSVDIN2                     (5'b00000),
        .PMARSVDIN                      (5'b00000),
        .PMARSVDIN2                     (5'b00000),
        .TSTIN                          (20'b11111111111111111111),
        .TSTOUT                         (/* Unused */),
        //-------------------------------- Channel ---------------------------------
        .CLKRSVD                        (4'b0000),
        //------------------------ Channel - Clocking Ports ------------------------
        .GTGREFCLK                      (1'b0),
        .GTNORTHREFCLK0                 (1'b0),
        .GTNORTHREFCLK1                 (1'b0),
        .GTREFCLK0                      (i_refclk),
        .GTREFCLK1                      (1'b0),
        .GTSOUTHREFCLK0                 (1'b0),
        .GTSOUTHREFCLK1                 (1'b0),
        //-------------------------- Channel - DRP Ports  --------------------------
        .DRPADDR                        (9'b000000000),
        .DRPCLK                         (1'b0),
        .DRPDI                          (1'b0),
        .DRPDO                          (/* Unused */),
        .DRPEN                          (1'b0),
        .DRPRDY                         (/* Unused */),
        .DRPWE                          (1'b0),
        //----------------------------- Clocking Ports -----------------------------
        .GTREFCLKMONITOR                (/* GTREFCLKMONITOR */),
        .QPLLCLK                        (/* Left Floating */),
        .QPLLREFCLK                     (/* Left Floating */),
        .RXSYSCLKSEL                    (2'b00),
        .TXSYSCLKSEL                    (2'b11),    //TODO FIXME
        //------------------------- Digital Monitor Ports --------------------------
        .DMONITOROUT                    (/* Unused */),
        //--------------- FPGA TX Interface Datapath Configuration  ----------------
        .TX8B10BEN                      (1'b0),
        //----------------------------- Loopback Ports -----------------------------
        .LOOPBACK                       (3'b000),
        //--------------------------- PCI Express Ports ----------------------------
        .PHYSTATUS                      (/* Unused */),
        .RXRATE                         (3'b000),
        .RXVALID                        (/* Unused */),
        //---------------------------- Power-Down Ports ----------------------------
        .RXPD                           (2'b00),
        .TXPD                           (2'b00),
        //------------------------ RX 8B/10B Decoder Ports -------------------------
        .SETERRSTATUS                   (1'b0),
        //------------------- RX Initialization and Reset Ports --------------------
        .EYESCANRESET                   (1'b0),
        .RXUSERRDY                      (1'b0),
        //------------------------ RX Margin Analysis Ports ------------------------
        .EYESCANDATAERROR               (/* Unused */),
        .EYESCANMODE                    (1'b0),
        .EYESCANTRIGGER                 (1'b0),
        //----------------------- Receive Ports - CDR Ports ------------------------
        .RXCDRFREQRESET                 (1'b0),
        .RXCDRHOLD                      (1'b0),
        .RXCDRLOCK                      (/* Unused */),
        .RXCDROVRDEN                    (1'b0),
        .RXCDRRESET                     (1'b0),
        .RXCDRRESETRSV                  (1'b0),
        //----------------- Receive Ports - Clock Correction Ports -----------------
        .RXCLKCORCNT                    (/* Unused */),
        //-------- Receive Ports - FPGA RX Interface Datapath Configuration --------
        .RX8B10BEN                      (1'b0),
        //---------------- Receive Ports - FPGA RX Interface Ports -----------------
        .RXUSRCLK                       (i_rx_usrclk),
        .RXUSRCLK2                      (i_rx_usrclk2),
        //---------------- Receive Ports - FPGA RX interface Ports -----------------
        .RXDATA                         ({rxdata_unused, o_rxdata}),
        .RXDATAVALID                    (o_rxdatavaild),
        .RXGEARBOXSLIP                  (i_rxslip),
        .RXHEADER                       ({rxheader_unused, o_rxheader}),
        .RXHEADERVALID                  (o_rxheader_valid),
        .RXSTARTOFSEQ                   (o_rxstartofseq),
        //----------------- Receive Ports - Pattern Checker Ports ------------------
        .RXPRBSERR                      (/* Unused */),
        .RXPRBSSEL                      (3'b000),   //No prbs
        //----------------- Receive Ports - Pattern Checker ports ------------------
        .RXPRBSCNTRESET                 (1'b0),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .RXDISPERR                      (/* Unused */),
        .RXNOTINTABLE                   (/* Unused */),
        //------------------------- Receive Ports - RX AFE -------------------------
        .GTXRXP                         (i_rx_p),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .GTXRXN                         (i_rx_n),
        //----------------- Receive Ports - RX Buffer Bypass Ports -----------------
        .RXBUFRESET                     (1'b0),
        .RXBUFSTATUS                    (/* Unused */),
        .RXDDIEN                        (1'b1),
        .RXDLYBYPASS                    (1'b0),
        .RXDLYEN                        (1'b0),
        .RXDLYOVRDEN                    (1'b0),
        .RXDLYSRESET                    (1'b0),
        .RXDLYSRESETDONE                (/* Unused */),
        .RXPHALIGN                      (1'b0),
        .RXPHALIGNDONE                  (/* Unused */),
        .RXPHALIGNEN                    (1'b0),
        .RXPHDLYPD                      (1'b0),
        .RXPHDLYRESET                   (1'b0),
        .RXPHMONITOR                    (/* Unused */),
        .RXPHOVRDEN                     (1'b0),
        .RXPHSLIPMONITOR                (/* Unused */),
        .RXSTATUS                       (o_rx_status),
        //------------ Receive Ports - RX Byte and Word Alignment Ports ------------
        .RXBYTEISALIGNED                (/* Unused */),
        .RXBYTEREALIGN                  (/* Unused */),
        .RXCOMMADET                     (/* Unused */),
        .RXCOMMADETEN                   (1'b0),
        .RXMCOMMAALIGNEN                (1'b0),
        .RXPCOMMAALIGNEN                (1'b0),
        //---------------- Receive Ports - RX Channel Bonding Ports ----------------
        .RXCHANBONDSEQ                  (/* Unused */),
        .RXCHBONDEN                     (1'b0),
        .RXCHBONDLEVEL                  (3'b000),
        .RXCHBONDMASTER                 (1'b0),
        .RXCHBONDO                      (/* Unused */),
        .RXCHBONDSLAVE                  (1'b0),
        //--------------- Receive Ports - RX Channel Bonding Ports  ----------------
        .RXCHANISALIGNED                (/* Unused */),
        .RXCHANREALIGN                  (/* Unused */),
        //------------------ Receive Ports - RX Equailizer Ports -------------------
        .RXLPMEN                        (1'b1),     //Use LPM not DFE for the moment
        .RXDFELPMRESET                  (i_lpm_reset),
        .RXOSHOLD                       (1'b0),
        .RXOSOVRDEN                     (1'b0),
        .RXLPMHFHOLD                    (1'b0), //Low frequency loop adapt
        .RXLPMHFOVRDEN                  (1'b0),
        .RXLPMLFHOLD                    (1'b0), //High frequency loop adapt
        .RXLPMLFKLOVRDEN                (1'b0),
        //DFE Inputs
        .RXDFEAGCHOLD                   (1'b0), 
        .RXDFEAGCOVRDEN                 (1'b0),
        .RXDFELFHOLD                    (1'b0), 
        .RXDFELFOVRDEN                  (1'b0),
        .RXDFEUTHOLD                    (1'b0), 
        .RXDFEUTOVRDEN                  (1'b0),
        .RXDFEVPHOLD                    (1'b0),
        .RXDFEVPOVRDEN                  (1'b0),
        .RXDFETAP2HOLD                  (1'b0),
        .RXDFETAP2OVRDEN                (1'b0),
        .RXDFETAP3HOLD                  (1'b0),
        .RXDFETAP3OVRDEN                (1'b0),
        .RXDFETAP4HOLD                  (1'b0),
        .RXDFETAP4OVRDEN                (1'b0),
        .RXDFETAP5HOLD                  (1'b0),
        .RXDFETAP5OVRDEN                (1'b0),
        .RXDFECM1EN                     (1'b0),
        .RXDFEXYDHOLD                   (1'b0),
        .RXDFEXYDOVRDEN                 (1'b0),

        .RXMONITORSEL                   (2'b01),    //Select AGC for monitoring
        .RXMONITOROUT                   (/* Unused */),
        //------------------ Receive Ports (GTH ONLY) - RX Equailizer Ports -------------------
        .RXDFEVSEN                      (1'b0),
        .RXDFEXYDEN                     (1'b1),
        //---------- Receive Ports - RX Fabric ClocK Output Control Ports ----------
        .RXRATEDONE                     (/* Unused */),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .RXOUTCLK                       (o_rxout_clk),
        .RXOUTCLKFABRIC                 (/* Unused */),
        .RXOUTCLKPCS                    (/* Unused */),
        .RXOUTCLKSEL                    (3'b010), //Choose The recovered clock
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .GTRXRESET                      (i_gtx_rx_reset),
        .RXOOBRESET                     (1'b0),
        .RXPCSRESET                     (1'b0),
        .RXPMARESET                     (1'b0),
        //----------------- Receive Ports - RX OOB Signaling ports -----------------
        .RXCOMSASDET                    (/* Unused */),
        .RXCOMWAKEDET                   (/* Unused */),
        //---------------- Receive Ports - RX OOB Signaling ports  -----------------
        .RXCOMINITDET                   (/* Unused */),
        //---------------- Receive Ports - RX OOB signalling Ports -----------------
        .RXELECIDLE                     (/* Unused */),
        .RXELECIDLEMODE                 (2'b11),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .RXPOLARITY                     (i_rx_polarity),
        //-------------------- Receive Ports - RX gearbox ports --------------------
        .RXSLIDE                        (1'b0),
        //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        .RXCHARISCOMMA                  (/* Unused */),
        .RXCHARISK                      (/* Unused */),
        //---------------- Receive Ports - Rx Channel Bonding Ports ----------------
        .RXCHBONDI                      (5'b00000),
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .RXRESETDONE                    (o_rx_reset_done),
        //------------------------------ Rx AFE Ports ------------------------------
        .RXQPIEN                        (1'b0),
        .RXQPISENN                      (/* Unused */),
        .RXQPISENP                      (/* Unused */),

        //############
        //############      TX
        //############

        //------------------------- TX Buffer Bypass Ports -------------------------
        .TXPHDLYTSTCLK                  (1'b0),
        //---------------------- TX Configurable Driver Ports ----------------------
        .TXPOSTCURSOR                   (5'b00000),
        .TXPOSTCURSORINV                (1'b0),
        .TXPRECURSOR                    (5'b00000),
        .TXPRECURSORINV                 (1'b0),
        .TXQPIBIASEN                    (1'b0),
        .TXQPISTRONGPDOWN               (1'b0),
        .TXQPIWEAKPUP                   (1'b0),
        //------------------- TX Initialization and Reset Ports --------------------
        .CFGRESET                       (1'b0),
        .GTTXRESET                      (i_gtx_tx_reset),
        .PCSRSVDOUT                     (/* Unused */),
        .TXUSERRDY                      (1'b0),
        //-------------------- Transceiver Reset Mode Operation --------------------
        .GTRESETSEL                     (1'b0),
        .RESETOVRD                      (1'b0),
        //-------------- Transmit Ports - 8b10b Encoder Control Ports --------------
        .TXCHARDISPMODE                 (8'h00),
        .TXCHARDISPVAL                  (8'h00),
        //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
        .TXUSRCLK                       (1'b0),
        .TXUSRCLK2                      (1'b0),
        //------------------- Transmit Ports - PCI Express Ports -------------------
        .TXELECIDLE                     (1'b0),
        .TXMARGIN                       (3'b000),
        .TXRATE                         (3'b001),
        .TXSWING                        (1'b0),
        //---------------- Transmit Ports - Pattern Generator Ports ----------------
        .TXPRBSFORCEERR                 (1'b0),
        //---------------- Transmit Ports - TX Buffer Bypass Ports -----------------
        .TXDLYBYPASS                    (1'b0),
        .TXDLYEN                        (1'b0),
        .TXDLYHOLD                      (1'b0),
        .TXDLYOVRDEN                    (1'b0),
        .TXDLYSRESET                    (1'b0),
        .TXDLYSRESETDONE                (/* Unused */),
        .TXDLYUPDOWN                    (1'b0),
        .TXPHALIGN                      (1'b0),
        .TXPHALIGNDONE                  (/* Unused */),
        .TXPHALIGNEN                    (1'b0),
        .TXPHDLYPD                      (1'b0),
        .TXPHDLYRESET                   (1'b0),
        .TXPHINIT                       (1'b0),
        .TXPHINITDONE                   (/* Unused */),
        .TXPHOVRDEN                     (1'b0),
        //-------------------- Transmit Ports - TX Buffer Ports --------------------
        .TXBUFSTATUS                    (/* Unused */),
        //------------- Transmit Ports - TX Configurable Driver Ports --------------
        .TXBUFDIFFCTRL                  (3'b100),
        .TXDEEMPH                       (1'b0),
        .TXDIFFCTRL                     (1'b0),
        .TXDIFFPD                       (1'b0),
        .TXINHIBIT                      (1'b0),
        .TXMAINCURSOR                   (5'b00000),
        .TXPISOPD                       (1'b0),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .TXDATA                         (32'h00000000),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .GTXTXN                         (/* Unused */),
        .GTXTXP                         (/* Unused */),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .TXOUTCLK                       (/* Unused */),
        .TXOUTCLKFABRIC                 (/* Unused */),
        .TXOUTCLKPCS                    (/* Unused */),
        .TXOUTCLKSEL                    (3'b011),
        .TXRATEDONE                     (/* Unused */),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .TXCHARISK                      (8'h00),
        .TXGEARBOXREADY                 (/* Unused */),
        .TXHEADER                       (3'b000),
        .TXSEQUENCE                     (7'b0000000),
        .TXSTARTSEQ                     (1'b0),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .TXPCSRESET                     (1'b0),
        .TXPMARESET                     (1'b0),
        .TXRESETDONE                    (/* Unused */),
        //---------------- Transmit Ports - TX OOB signalling Ports ----------------
        .TXCOMFINISH                    (/* Unused */),
        .TXCOMINIT                      (1'b0),
        .TXCOMSAS                       (1'b0),
        .TXCOMWAKE                      (1'b0),
        .TXPDELECIDLEMODE               (1'b0),
        //--------------- Transmit Ports - TX Polarity Control Ports ---------------
        .TXPOLARITY                     (1'b0),
        //------------- Transmit Ports - TX Receiver Detection Ports  --------------
        .TXDETECTRX                     (1'b0),
        //---------------- Transmit Ports - TX8b/10b Encoder Ports -----------------
        .TX8B10BBYPASS                  (8'h00),
        //---------------- Transmit Ports - pattern Generator Ports ----------------
        .TXPRBSSEL                      (3'b000),
        //--------------------- Tx Configurable Driver  Ports ----------------------
        .TXQPISENN                      (/* Unused */),
        .TXQPISENP                      (/* Unused */)

    );

endmodule

`resetall
