function [txPSDU, end_time]= Rtop_tx(cfgHE)
% addpath '..\'
addpath library\
yunsdr_init.ipaddr = '192.168.1.10';

% Signal generation
transmitPower = 15; %dBm
A = 10.^((transmitPower-30)/20);
psduLength = getPSDULength(cfgHE);
txPSDU = randi([0 1],psduLength*8,1);
tx_11ax = wlanWaveformGenerator(txPSDU,cfgHE);%,'OversamplingFactor',2);
end_time = length(tx_11ax);
% disp(['Original signal power is ' num2str(sum(abs(tx_11ax).^2)/length(tx_11ax)) 'W'])
% end_time = length(tx_11ax);
fs = wlanSampleRate(cfgHE);
txdata=repmat([zeros(size(tx_11ax));A*tx_11ax],1,1);
c = max(max([abs(real(txdata)),abs(imag(txdata))]));
coff = 25000/c;
txdata = round(txdata.*coff);
% psdCal(txdata,fs);
% P = sum(abs(txdata).^2)/length(txdata)*2;
% disp(['Transmitting signal PSD is ' num2str(10*log10(P*1000)) 'dBm']);

yunsdr_init.txgap = 0;
yunsdr_init.samp=40e6;                  % sample freq 4e6~61.44e6
yunsdr_init.bw=20e6;                    % tx analog flter  bandwidth 250e3~56e6
yunsdr_init.freq=4300e6;                % tx LO freq 70e6~6000e6
yunsdr_init.tx_att1=10e3;                  % tx att ch1 0~89e3 mdB   1mdB=0.001dB
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
    disp(['txdata is ',num2str(size(txdata,2)),' stream, has exceed the maximum of supported stream!']);
    return;
else
    ret=send_to_yunsdr(txdata,yunsdr_init);
end
end