% clearvars -except times;close all;warning off;
source='file';% file or yunsdr
data_type='ieee802_11ax';
yunsdr_init.ipaddr='192.168.1.10';
yunsdr_init.rxsamples=1e6; % receive data in samples
if contains(source, 'file')
    %% load from file
    rxdata=load_from_file;
    rxdata = add_user_channel(rxdata,0,20,1);
else
    %% load from yunsdr
    yunsdr_init.samp=40e6;                 % sample freq 4e6~61.44e6
    yunsdr_init.bw=20e6;                   % tx analog flter  bandwidth 250e3~56e6
    yunsdr_init.freq=4300e6;                % rx LO freq 70e6~6000e6
    yunsdr_init.rxgain_mode1='RF_GAIN_MGC'; % RF_GAIN_MGC,RF_GAIN_FASTATTACK_AGC,RF_GAIN_SLOWATTACK_AGC
    yunsdr_init.rxgain_mode2='RF_GAIN_MGC'; % RF_GAIN_MGC,RF_GAIN_FASTATTACK_AGC,RF_GAIN_SLOWATTACK_AGC
    yunsdr_init.rxgain1=30;                 % rx mgc gain ch1 0~70 dB
    yunsdr_init.rxgain2=5;                  % rx mgc gain ch2 0~70 dB
    yunsdr_init.fdd_tdd='FDD';              % FDD,TDD
    yunsdr_init.trx_sw='RX';                % TX,RX
    yunsdr_init.rx_chan='RX1_CHANNEL';      % RX1_CHANNEL,RX2_CHANNEL,RX_DUALCHANNEL
    yunsdr_init.ref='INTERNAL_REFERENCE';   % INTERNAL_REFERENCE,EXTERNAL_REFERENCE
    yunsdr_init.vco_cal='AUXDAC1';          % AUXDAC1 ADF4001
    yunsdr_init.aux_dac1=0;                 % Voltage to change freq of vctcxo 0~3000mv
    % ***************tx mode*************** %
    % START_RX_BULK   rx without timestamp
    % START_RX_BURST  rx at systime count to timestamp
    yunsdr_init.rxmode='START_RX_BULK';
    % ************timestamp mode************ %
    % PPS_ALL_DISABLE pps disable
    % PPS_INTERNAL_EN pps from internal gps module
    % PPS_EXTERNAL_EN pps from external pps in port
    yunsdr_init.ppsmode='PPS_ALL_DISABLE';   % PPS
    % ************************************** %
    rxdata=load_from_yunsdr(yunsdr_init);
end

switch data_type
    case 'ieee802_11n'
        upsample=2;
        addpath ieee802_11n\receiver_matlab
        [data_byte_recv,sim_options] = ieee802_11n_rx_func(rxdata,upsample);
    case 'ieee802_11ax'
        addpath ieee802_11ax
        %         cfgHE = wlanHESUConfig;
        %         cfgHE.ChannelBandwidth = 'CBW20';
        %         cfgHE.NumSpaceTimeStreams = 1;
        %         cfgHE.NumTransmitAntennas = 1;
        %         cfgHE.APEPLength = 1e3;
        %         cfgHE.GuardInterval = 0.8;
        %         cfgHE.HELTFType = 4;
        %         cfgHE.ChannelCoding = 'BCC';
        %         cfgHE.MCS = 6;
        load('config.mat');
        data_rrxPSDUecv = ieee802_11ax_rx_func(rxdata,cfgHE);
end