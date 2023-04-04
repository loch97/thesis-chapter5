clearvars -except times;close all;warning off;
save_file=0;
send_yunsdr=1;
source='ieee802_11ax';
yunsdr_init.ipaddr='192.168.1.10';
switch source
    case 'ieee802_11n'
        addpath ieee802_11n\transmitter_matlab
        in_byte=repmat(1:96,1,5);
        mcs=7;
        upsample=2;
        tx_11n=ieee802_11n_tx_func(in_byte,mcs,upsample);
        txdata=repmat([zeros(size(tx_11n));tx_11n],1,1);
        yunsdr_init.txgap=0;
    case 'ieee802_11ax'
        addpath ieee802_11ax
        cfgHE = wlanHESUConfig;
        cfgHE.ChannelBandwidth = 'CBW20';
        cfgHE.NumSpaceTimeStreams = 1;
        cfgHE.NumTransmitAntennas = 1;
        cfgHE.APEPLength = 500;
        cfgHE.GuardInterval = 0.8;
        cfgHE.HELTFType = 1;
        cfgHE.ChannelCoding = 'BCC';
        cfgHE.MCS = 7;
        psduLength = getPSDULength(cfgHE);

        txPSDU = randi([0 1],psduLength*8,1);
        tx_11ax = wlanWaveformGenerator(txPSDU,cfgHE);
        fs = wlanSampleRate(cfgHE);
        psdCal(tx_11ax,fs);
        txdata=repmat([zeros(size(tx_11ax));tx_11ax./100],1,1);
        yunsdr_init.txgap=0;
end
%% save to file
if save_file==1
    ret=save_to_file(txdata,1);
end
%% send to yunsdr
if send_yunsdr==1
    yunsdr_init.samp=20e6;                  % sample freq 4e6~61.44e6
    yunsdr_init.bw=20e6;                    % tx analog flter  bandwidth 250e3~56e6
    yunsdr_init.freq=4300e6;                % tx LO freq 70e6~6000e6
    yunsdr_init.tx_att1=20e3;               % tx att ch1 0~89e3 mdB
    yunsdr_init.tx_att2=20e3;               % tx att ch2 0~89e3 mdB
    yunsdr_init.fdd_tdd='FDD';              % FDD,TDD
    yunsdr_init.trx_sw='TX';                % TX,RX
    yunsdr_init.tx_chan='TX1_CHANNEL';      % TX1_CHANNEL,TX2_CHANNEL,TX_DUALCHANNEL
    yunsdr_init.ref='INTERNAL_REFERENCE';   % INTERNAL_REFERENCE,EXTERNAL_REFERENCE
    yunsdr_init.vco_cal='AUXDAC1';          % AUXDAC1 ADF4001
    yunsdr_init.aux_dac1=0;                 % Voltage to change freq of vctcxo 0~3000mv
    % ***************tx mode*************** %
    % START_TX_NORMAL stream mode tx send immediately without timestamp
    % START_TX_LOOP   LOOP mode tx send loop and loop without timestamp
    % START_TX_BURST  Burst mode tx send until systime count to timestamp
    % txgap in START_TX_NORMAL and START_TX_LOOP mode is gap nanosecond
    % txgap in START_TX_BURST mode  txtime = read systime + txgap(nanosecond)
    yunsdr_init.txmode='START_TX_LOOP';

    % ************timestamp mode************ %
    % PPS_ALL_DISABLE pps disable
    % PPS_INTERNAL_EN pps from internal gps module
    % PPS_EXTERNAL_EN pps from external pps in port
    yunsdr_init.ppsmode='PPS_ALL_DISABLE';   % PPS
    % ************************************** %

    if size(txdata,2)>2
        disp(['txdata is ',num2str(size(txdata,2)),' stream, has exceed 2 max!']);
        return;
    else
        ret=send_to_yunsdr(txdata,yunsdr_init);
    end
end