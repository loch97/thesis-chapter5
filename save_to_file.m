function ret=save_to_file(tx)
%% to modelsim
c1=max(max([abs(real(tx)),abs(imag(tx))]));
index=25000/c1;
txdata=round(tx.*index);
for i=1:size(txdata,2)
%     file_name=['at',num2str(i)];
    fid = fopen('data.txt', 'wt');
    for j=1:size(txdata,1)
        fprintf(fid,'%8.0f%8.0f\n',real(txdata(j,i)),imag(txdata(j,i)));
    end
end
% %% save to .dat
% % add pad
% rem=-1;
% while (rem<0)
%     rem=1024*2^i-size(txdata,1);
%     i=i+1;
% end
% % txdata1=[txdata;zeros(rem,size(txdata,2))];
% txdata1=txdata;
% for i=1:size(txdata,2)
%     file_name=['at',num2str(i)];
%     B=zeros(size(txdata1,1)*2,1);
%     B(1:2:end)=real(txdata1(:,i));
%     B(2:2:end)=imag(txdata1(:,i));
%     fid2=fopen(['data\1_16bit_',file_name,'.dat'],'w');
%     fwrite(fid2,B,'int16');
%     fclose('all');
% end
% %% save to litepoint
% % if upsample==1 || upsample==2 
% %     ups=4/upsample;
% %     flt1=rcosine(1,ups,'fir/sqrt',0.05,64);
% %     tx_signal2=rcosflt(txd,1,ups, 'filter', flt1);
% % elseif upsample>2
% %     downs=upsample/4;
% %     tx_signal2=txd(1:downs:end,:);
% % end
% % template=importdata('E:\matlab_work\litepoint\mcs0_100.mat');
% % info2=template.info2;
% % wavelp=template.wavelp;
% % wave=tx_signal2(:,1);
% % for i=1:size(tx_signal2,2)
% %     if size(tx_signal2,2)==1
% %         wavelp.vsg.wave.data=tx_signal2(:,1);
% %     else
% %         wavelp.vsg.wave(1,i).data=tx_signal2(:,i);
% %     end
% % end
% % save(['data\1.mat'],'info2','wavelp','wave');
ret='save to file ok';
% disp('save to file ok');