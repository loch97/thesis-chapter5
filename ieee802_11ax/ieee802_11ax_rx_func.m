function data_recv = ieee802_11ax_rx_func(rx,cfgHE)
ind = wlanFieldIndices(cfgHE);
chanBW = cfgHE.ChannelBandwidth;
fs = wlanSampleRate(cfgHE);
ofdmInfo = wlanHEOFDMInfo('HE-Data',cfgHE);

coarsePktOffset = wlanPacketDetect(rx,chanBW);

% Extract L-STF and perform coarse frequency offset correction
lstf = rx(coarsePktOffset+(ind.LSTF(1):ind.LSTF(2)),:);
coarseFreqOff = wlanCoarseCFOEstimate(lstf,chanBW);
rx = helperFrequencyOffset(rx,fs,-coarseFreqOff);

% Extract the non-HT fields and determine fine packet offset
nonhtfields = rx(coarsePktOffset+(ind.LSTF(1):ind.LSIG(2)),:);
finePktOffset = wlanSymbolTimingEstimate(nonhtfields,chanBW);

% Determine final packet offset
pktOffset = coarsePktOffset+finePktOffset;


% Extract L-LTF and perform fine frequency offset correction
rxLLTF = rx(pktOffset+(ind.LLTF(1):ind.LLTF(2)),:);
fineFreqOff = wlanFineCFOEstimate(rxLLTF,chanBW);
rx = helperFrequencyOffset(rx,fs,-fineFreqOff);

% HE-LTF demodulation and channel estimation
rxHELTF = rx(pktOffset+(ind.HELTF(1):ind.HELTF(2)),:);
heltfDemod = wlanHEDemodulate(rxHELTF,'HE-LTF',cfgHE);
[chanEst,pilotEst] = heLTFChannelEstimate(heltfDemod,cfgHE);

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
refSym = wlanReferenceSymbols(cfgHE); % Reference constellation
bfConst = hePlotConstellation(eqDataSym,refSym,'Equalized Symbols');
% Recover data
data_recv = wlanHEDataBitRecover(eqDataSym,nVarEst,csi,cfgHE);
pause(10);
end

