function rxPSDU = ieee802_11ax_rx_func_res(rx,cfgHE)

%% EVM configuration
EVM = comm.EVM;
EVM.ReferenceSignalSource = 'Estimated from reference constellation';
EVM.Normalization = "Average constellation power";
EVM.ReferenceConstellation = wlanReferenceSymbols(cfgHE);
EVM.AveragingDimensions = [1 2 3];

BERthre = 1e-6;
ind = wlanFieldIndices(cfgHE);
chanBW = cfgHE.ChannelBandwidth;
fs = wlanSampleRate(cfgHE);
ofdmInfo = wlanHEOFDMInfo('HE-Data',cfgHE);
load('txPSDU.mat','txPSDU','end_time');

num = 1;
while(num)
    disp(['Countdown Num: ' num2str(num)])
%     figure('name','IEEE802.11ax接收端PHY演示')
    figure(1)
    subplot(121)
    plot(1:size(rx(:,1)),real(rx(:,1)))
    axis([1,size(rx,1),-32768,32767])
    title('接收信号时域波形')
    xlabel('时间')
    ylabel('数值')
    figure(2)
    subplot(121)
    pwelch(rx,[],[],[],fs,'centered','psd');
    title('接收信号功率谱密度');

    % Frame head searching
    coarsePktOffset = wlanPacketDetect(rx,chanBW);
    if isempty(coarsePktOffset)
        disp('未检测到数据帧')
        break;
    end

    % Extract L-STF and perform coarse frequency offset correction
    lstf = rx(coarsePktOffset+(ind.LSTF(1):ind.LSTF(2)),:);
    coarseFreqOff = wlanCoarseCFOEstimate(lstf,chanBW);
    rx = helperFrequencyOffset(rx,fs,-coarseFreqOff);
    figure(3)
    subplot(121)
    plot(1:size(coarsePktOffset:end_time+coarsePktOffset,2),abs(rx(coarsePktOffset:end_time+coarsePktOffset,1)))
    title('粗同步信号时域波形');
    set(gca,'XLim', [0 end_time])
    xlabel('时间')
    ylabel('数值')

    % Extract the non-HT fields and determine fine packet offset
    nonhtfields = rx(coarsePktOffset+(ind.LSTF(1):ind.LSIG(2)),:);
    finePktOffset = wlanSymbolTimingEstimate(nonhtfields,chanBW);

    % Determine final packet offset
    pktOffset = coarsePktOffset+finePktOffset;

    % Extract L-LTF and perform fine frequency offset correction
    rxLLTF = rx(pktOffset+(ind.LLTF(1):ind.LLTF(2)),:);
    fineFreqOff = wlanFineCFOEstimate(rxLLTF,chanBW);
    rx = helperFrequencyOffset(rx,fs,-fineFreqOff);
    figure(3)
    subplot(122)
    plot(1:size(pktOffset:pktOffset+end_time,2),abs(rx(pktOffset:pktOffset+end_time,1)))
    title('精同步信号时域波形');
    set(gca,'XLim', [0 end_time])
    xlabel('时间')
    ylabel('数值')

    % HE-LTF demodulation and channel estimation
    rxHELTF = rx(pktOffset+(ind.HELTF(1):ind.HELTF(2)),:);
    heltfDemod = wlanHEDemodulate(rxHELTF,'HE-LTF',cfgHE);
    [chanEst,pilotEst] = heLTFChannelEstimate(heltfDemod,cfgHE);
    figure(2)
    subplot(122)
    plot(1:length(chanEst),20*log10(abs(chanEst)))
    title('HE-LTF信道估计结果');
    xlabel('子载波个数')
    ylabel('信道估计数值(dB)')
    set(gca,'XLim', [0 length(chanEst)])

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
    figure(1)
    subplot(122)
    plot(real(symPlot(:,1)),imag(symPlot(:,1)),'.');
    axis([-1.5,1.5,-1.5,1.5]);
    title('信道均衡后星座图');

    % Recover data
    rxPSDU = wlanHEDataBitRecover(eqDataSym,nVarEst,csi,cfgHE);

    % SNR estimation per receive antenna
    powHELTF = mean(rxHELTF.*conj(rxHELTF));
    estSigPower = powHELTF-nVarEst;
    estimatedSNR = 10*log10(mean(estSigPower./nVarEst));
%     disp(['Estimated SNR is ' num2str(estimatedSNR)])
    [~,ber] = biterr(rxPSDU,txPSDU);
    disp(['BER of the frame is ' num2str(ber)])
    rmsEVM = EVM(eqDataSym);
%     disp(['rmsEVM of the frame is ' num2str(rmsEVM) '% or ' num2str(20*log10(rmsEVM/100)) 'dB'])
    [codeRate,modOrder,name] = getMCSparameter(cfgHE);
    disp('---------通信系统参数---------')
    disp(['MCS: ' num2str(cfgHE.MCS) ',调制方式: ' num2str(name) ',码率: ' codeRate])
    disp(['传输速率: ' num2str(8*cfgHE.APEPLength*(ber == 0)/sum(end_time/fs)/1e6) 'Mbps'])
    disp(['接收端估计SNR: ' num2str(estimatedSNR) 'dB'])
    disp(['当前接收数据帧的BER: ' num2str(ber)])
    disp(['接收数据星座图的EVM: ',num2str(20*log10(rmsEVM/100)) 'dB'])
%     GAP = -1.5/log(5*BERthre);
%     text(0.1,0.2,['遍历容量（带GAP）: ' num2str(20e6*log2(1+10^(estimatedSNR/10)/GAP)/1e6) 'Mbps'])
%     text(0.1,0.4,['精频偏估计值: ' num2str(fineFreqOff)])
    num = num - 1;
    RXdata = rx(pktOffset:pktOffset+end_time);
    rx = rx(pktOffset+end_time:end,1);
    P = sum(abs(RXdata).^2)/length(end_time);
%     disp(['Received Signal Power is ' num2str(10*log10(1000*P)) 'dbm'])
end
end

