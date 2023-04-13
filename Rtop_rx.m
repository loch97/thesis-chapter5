function [rxPSDU, cfgHE, snrInd, estimatedSNR] = Rtop_rx(cfgHE,snrInd,end_time)
% addpath '..\'
addpath ieee802_11ax\

% return parameters initialization
rxPSDU = 0;
estimatedSNR = 0;

yunsdr_init.ipaddr='192.168.1.10';
yunsdr_init.rxsamples=2e5; % receive data in samples

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
rx=load_from_yunsdr(yunsdr_init);
% rx = rx(2000:end,:);
%% Rate Control Algorithm Parameters
rcaAttack = 0;  % Control the sensitivity when MCS is increasing
rcaRelease = 1; % Control the sensitivity when MCS is decreasing
threshold = [3 10 14 18 24 29];
snrUp = [threshold inf]+rcaAttack;
snrDown = [-inf threshold]-rcaRelease;

%% EVM configuration
EVM = comm.EVM;
EVM.ReferenceSignalSource = 'Estimated from reference constellation';
EVM.Normalization = "Average constellation power";
EVM.ReferenceConstellation = wlanReferenceSymbols(cfgHE);
EVM.AveragingDimensions = [1 2 3];

% BERthre = 1e-6;
ind = wlanFieldIndices(cfgHE);
chanBW = cfgHE.ChannelBandwidth;
fs = wlanSampleRate(cfgHE);
ofdmInfo = wlanHEOFDMInfo('HE-Data',cfgHE);
% load('txPSDU.mat','txPSDU','end_time');


% figure('name','IEEE802.11ax接收端PHY演示')
% clf
% subplot(241)
% plot(1:size(rx(:,1)),real(rx(:,1)))
% hold on
% axis([1,size(rx,1),-32768,32767])
% title('原始信号时域波形')
% hold off
% subplot(242)
% pwelch(rx,[],[],[],fs,'centered','psd');
% title('原始信号功率谱密度');

num = 2;
while(num)
    % Frame head searching
    coarsePktOffset = wlanPacketDetect(rx,chanBW);
    if isempty(coarsePktOffset)
        %         disp('未检测到数据帧')
        %         figure
        %         plot(real(rx))
        %         cfgHE.MCS = 0;
        rx = rx(end_time:end);
        num = num-1;
        continue
        %         psduLength = getPSDULength(cfgHE);
        %         rxPSDU = zeros(psduLength*8,1);
        %         return
    end

    % Extract L-STF and perform coarse frequency offset correction
    lstf = rx(coarsePktOffset+(ind.LSTF(1):ind.LSTF(2)),:);
    coarseFreqOff = wlanCoarseCFOEstimate(lstf,chanBW);
    rx = helperFrequencyOffset(rx,fs,-coarseFreqOff);
    % subplot(243)
    % plot(1:size(coarsePktOffset:end_time+coarsePktOffset,2),abs(rx(coarsePktOffset:end_time+coarsePktOffset,1)))
    % title('粗同步信号时域波形');
    % set(gca,'XLim', [0 end_time])

    % Extract the non-HT fields and determine fine packet offset
    nonhtfields = rx(coarsePktOffset+(ind.LSTF(1):ind.LSIG(2)),:);
    finePktOffset = wlanSymbolTimingEstimate(nonhtfields,chanBW);

    % Determine final packet offset
    pktOffset = coarsePktOffset+finePktOffset;

    if pktOffset<0
        rx = rx(end_time:end);
        num = num-1;
        continue
    end

    % Extract L-LTF and perform fine frequency offset correction
    rxLLTF = rx(pktOffset+(ind.LLTF(1):ind.LLTF(2)),:);
    fineFreqOff = wlanFineCFOEstimate(rxLLTF,chanBW);
    rx = helperFrequencyOffset(rx,fs,-fineFreqOff);
    % subplot(245)
    % plot(1:size(pktOffset:pktOffset+end_time,2),abs(rx(pktOffset:pktOffset+end_time,1)))
    % title('精同步信号时域波形');
    % set(gca,'XLim', [0 end_time])

    % HE-LTF demodulation and channel estimation
    rxHELTF = rx(pktOffset+(ind.HELTF(1):ind.HELTF(2)),:);
    heltfDemod = wlanHEDemodulate(rxHELTF,'HE-LTF',cfgHE);
    [chanEst,pilotEst] = heLTFChannelEstimate(heltfDemod,cfgHE);
    % subplot(246)
    % plot(1:length(chanEst),20*log10(abs(chanEst)))
    % title('HE-LTF信道估计结果');
    % set(gca,'XLim', [0 length(chanEst)])

    % Data demodulate
    rxData = rx(pktOffset+(ind.HEData(1):ind.HEData(2)),:);
    demodSym = wlanHEDemodulate(rxData,'HE-Data',cfgHE);

    % Pilot phase tracking
    %         demodSym = heCommonPhaseErrorTracking(demodSym,chanEst,cfgHE);
    pilotEstTrack = mean(pilotEst,2);
    demodSym = heCommonPhaseErrorTracking(demodSym,pilotEstTrack,cfgHE);

    % Estimate noise power in HE fields
    nVarEst = heNoiseEstimate(demodSym(ofdmInfo.PilotIndices,:,:),pilotEst,cfgHE);
    %         nVarEstlist(numPkt) = nVarEst;
    % Extract data subcarriers from demodulated symbols and channel
    % estimate
    demodDataSym = demodSym(ofdmInfo.DataIndices,:,:);
    chanEstData = chanEst(ofdmInfo.DataIndices,:,:);

    % Equalization and STBC combining
    [eqDataSym,csi] = heEqualizeCombine(demodDataSym,chanEstData,nVarEst,cfgHE);
    % refSym = wlanReferenceSymbols(cfgHE); % Reference constellation
    % bfConst = hePlotConstellation(eqDataSym,refSym,'Equalized Symbols');
    [Nsd,NSym,Nss] = size(eqDataSym);
    symPlot = squeeze(reshape(eqDataSym(:,:,end:-1:1),Nsd*NSym,1,Nss));
    % subplot(247)
    % plot(real(symPlot(:,1)),imag(symPlot(:,1)),'.');
    % axis([-1.5,1.5,-1.5,1.5]);
    % title('信道均衡后星座图');

    % Recover data
    rxPSDU = wlanHEDataBitRecover(eqDataSym,nVarEst,csi,cfgHE);

    % SNR estimation per receive antenna
    powHELTF = mean(rxHELTF.*conj(rxHELTF));
    estSigPower = powHELTF-nVarEst;
    if estSigPower < 0
        rx = rx(end_time:end);
        num = num-1;
        continue
    end
    if num == 1
        estimatedSNR = 10*log10(mean(estSigPower./nVarEst));
        disp(['Estimated SNR is ' num2str(estimatedSNR)])
        % [~,ber] = biterr(rxPSDU,txPSDU);
        % disp(['BER of the frame is ' num2str(ber)])
        rmsEVM = EVM(eqDataSym);
        disp(['rmsEVM of the frame is ' num2str(rmsEVM) '% or ' num2str(20*log10(rmsEVM/100)) 'dB'])
        % RCA configuration
        increaseMCS = (mean(estimatedSNR) > snrUp((snrInd==0)+snrInd));
        decreaseMCS = (mean(estimatedSNR) <= snrDown((snrInd==0)+snrInd));
        snrInd = snrInd+increaseMCS-decreaseMCS;
        cfgHE.MCS = max(snrInd - 1,0);
    end
    num = num -1;
    rx = rx(pktOffset+end_time:end);
    % [codeRate,modOrder,name] = getMCSparameter(cfgHE);
    % subplot(248)
    % axis off
    % title('通信系统参数')
    % text(0.1,0.9,['MCS: ' num2str(cfgHE.MCS) ',调制方式: ' num2str(name) ',码率: ' codeRate])
    % text(0.1,0.7,['传输速率: ' num2str(8*cfgHE.APEPLength*(ber == 0)/sum(end_time/fs)/1e6) 'Mbps'])
    % text(0.1,0.5,['接收端估计SNR: ' num2str(estimatedSNR) 'dB'])
    % text(0.1,0.3,['BER: ' num2str(ber)])
    % text(0.1,0.1,['data星座图EVM: ',num2str(20*log10(rmsEVM/100)) 'dB'])
    % GAP = -1.5/log(5*BERthre);
    %     text(0.1,0.2,['遍历容量（带GAP）: ' num2str(20e6*log2(1+10^(estimatedSNR/10)/GAP)/1e6) 'Mbps'])
    %     text(0.1,0.4,['精频偏估计值: ' num2str(fineFreqOff)])
    % RXdata = rx(pktOffset:pktOffset+end_time);
    % rx = rx(pktOffset+end_time:end,1);
    % P = sum(abs(RXdata).^2)/length(end_time);
    % disp(['Received Signal Power is ' num2str(10*log10(1000*P)) 'dbm'])
end
end