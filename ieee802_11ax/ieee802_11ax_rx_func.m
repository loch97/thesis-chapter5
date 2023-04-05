function rxPSDU = ieee802_11ax_rx_func(rx,cfgHE)
ind = wlanFieldIndices(cfgHE);
chanBW = cfgHE.ChannelBandwidth;
fs = wlanSampleRate(cfgHE);
ofdmInfo = wlanHEOFDMInfo('HE-Data',cfgHE);
load('txPSDU.mat','txPSDU','end_time');

num = 5;
while(num)
    disp(['Countdown ' num2str(num)])
    figure(1)
    clf
    set(gcf,'name','IEEE802.11ax接收端PHY演示')
    subplot(231)
    plot(real(rx(:,1)))
    hold on
    axis([1,size(rx,1),-32768,32767])
    title('原始信号时域波形')
    hold off
    subplot(232)
    pwelch(rx,[],[],[],fs,'centered','psd');
    title('原始信号功率谱密度');

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
    subplot(233)
    plot(abs(rx(coarsePktOffset:end_time+coarsePktOffset,1)))
    title('粗同步能量检测');

    % Extract the non-HT fields and determine fine packet offset
    nonhtfields = rx(coarsePktOffset+(ind.LSTF(1):ind.LSIG(2)),:);
    finePktOffset = wlanSymbolTimingEstimate(nonhtfields,chanBW);

    % Determine final packet offset
    pktOffset = coarsePktOffset+finePktOffset;

    % Extract L-LTF and perform fine frequency offset correction
    rxLLTF = rx(pktOffset+(ind.LLTF(1):ind.LLTF(2)),:);
    fineFreqOff = wlanFineCFOEstimate(rxLLTF,chanBW);
    rx = helperFrequencyOffset(rx,fs,-fineFreqOff);
    subplot(234)
    plot(abs(rx(pktOffset:pktOffset+end_time,1)))
    title('精同步能量检测');

    % HE-LTF demodulation and channel estimation
    rxHELTF = rx(pktOffset+(ind.HELTF(1):ind.HELTF(2)),:);
    heltfDemod = wlanHEDemodulate(rxHELTF,'HE-LTF',cfgHE);
    [chanEst,pilotEst] = heLTFChannelEstimate(heltfDemod,cfgHE);
    subplot(235)
    plot(20*log10(abs(chanEst)))
    title('HE-LTF信道估计图');

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
    subplot(236)
    plot(real(symPlot(:,1)),imag(symPlot(:,1)),'.');
    axis([-1.5,1.5,-1.5,1.5]);
    title('信道均衡后星座图');

    % Recover data
    rxPSDU = wlanHEDataBitRecover(eqDataSym,nVarEst,csi,cfgHE);
    pause(10);

    % SNR estimation per receive antenna
    powHELTF = mean(rxHELTF.*conj(rxHELTF));
    estSigPower = powHELTF-nVarEst;
    estimatedSNR = 10*log10(mean(estSigPower./nVarEst));
    disp(['Estimated SNR is ' num2str(estimatedSNR)])
    [~,ber] = biterr(rxPSDU,txPSDU);
    disp(['BER of the frame is ' num2str(ber)])
    rx = rx(pktOffset+end_time:end,1);
    num = num - 1;
end
end

