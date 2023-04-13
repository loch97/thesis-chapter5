function psdCal(tx,fs)
%% psd
for i=1:size(tx,2)
    subplot(1,size(tx,2),i);
    pwelch(tx(:,i),[],[],[],2*fs,'centered','psd');
end
end

