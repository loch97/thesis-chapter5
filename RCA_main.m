clear
close all
warning off
clc

% global cfgHE
cfgHE = wlanHESUConfig;
cfgHE.ChannelBandwidth = 'CBW20';
cfgHE.NumSpaceTimeStreams = 1;
cfgHE.NumTransmitAntennas = 1;
cfgHE.APEPLength = 1000;
cfgHE.GuardInterval = 0.8;
cfgHE.HELTFType = 2;
cfgHE.ChannelCoding = 'BCC';
cfgHE.MCS = 0;                      % Initial Value of MCS is 2
snrInd = cfgHE.MCS; % Store the start MCS value

numPkt = 50;

MCSlist = zeros(1,numPkt);
BERlist = zeros(1,numPkt);
SNRlist = zeros(1,numPkt);
for i = 1:numPkt
    disp('----------start------------')
    disp(['Packet ' num2str(i) ' with MCS ' num2str(cfgHE.MCS)])
    MCSlist(i) = cfgHE.MCS;
    [txPSDU, end_time] = Rtop_tx(cfgHE);
    [rxPSUD,cfgHE,snrInd,measuredSNR] = Rtop_rx(cfgHE,snrInd,end_time);
    SNRlist(i) = measuredSNR;
    if sum(rxPSUD) == 0
        ber = 0.5;
        disp('未检测到数据帧')
    else
        [~,ber] = biterr(txPSDU,rxPSUD);
        disp(['BER of Packet ' num2str(i) ' is ' num2str(ber)])
    end
    BERlist(i) = ber;
    snrInd = snrInd - (ber>0);
    disp('-----------end-------------')
end

%% Plot result
figure
subplot(311)
plot(1:numPkt,MCSlist,'LineWidth',1)
xlabel('数据包个数')
ylabel('MCS数值')
set(gca,'YLim',[0,6])

subplot(312)
stem(find(BERlist==0),BERlist(BERlist==0),'o','LineWidth',1)
hold on
stem(find(BERlist>0),BERlist(BERlist>0),'or','LineWidth',1)
if any(BERlist)
    legend('解码成功','解码失败')
else
    legend('解码成功')
end
xlabel('数据包个数')
ylabel('BER')
set(gca,'YLim',[0,1])

subplot(313)
plot(1:numPkt,SNRlist,'LineWidth',1)
xlabel('数据包个数')
ylabel('估计SNR(dB)')
ylim([0 35])
