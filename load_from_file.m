function rx_signal=load_from_file
%% load modelsim 
[a1,a2]=textread('data.txt','%f%f'); % original text is data\1_at1.txt
% [a3 a4]=textread('dataat2.txt','%f%f');
% [a5 a6]=textread('dataat3.txt','%f%f');
% [a7 a8]=textread('dataat4.txt','%f%f');
% [a1 a2]=textread('E:\code\ieee802_11a\data\frame18_100_2up.txt','%f%f');
rx_signal(:,1)=a1+1i*a2;
% rx_signal(:,2)=a3+1i*a4;
% rx_signal(:,3)=a5+1i*a6;
% rx_signal(:,4)=a7+1i*a8;
%% yunsdr .mat
% rx_signal(:,1)=importdata('E:\code\ht7603\malab\ieee802.11a\data\20160325T134612.mat');
%% load .dat
% fid1=fopen('data\1.dat','r');
% A=fread(fid1,'int16');
% fclose('all');
% rx_signal=A(1:2:end)+1i*A(2:2:end);
% rx_signal2=rx_signal;
%% load dump
% fid1=fopen('E:\matlab_work\rxdata\2.dmp','r');
% data=fread(fid1,'int16');
% fclose('all');
% datadmp=reshape(data,64,length(data)/64);
% datao=datadmp(9:64,:);
% dataos=datao(:);
% a1=dataos(1:2:end);
% a2=dataos(2:2:end);
% a1=a1-mean(a1);
% a2=a2-mean(a2);
% rx_signal=a1+1i*a2;
%% load vivado
% run_hw_ila hw_ila_1
% display_hw_ila_data [upload_hw_ila_data hw_ila_1]
% write_hw_ila_data -csv_file E:/matlab_work/tcpip/ad9361_tone/data/data.csv [upload_hw_ila_data hw_ila_1] -force
% m = csvread('data\data.csv',2,0);
% d2un_q=bin2dec(num2str(m(:,7),14));
% d2un_i=bin2dec(num2str(m(:,8),14));
% d2un_q=bin2dec(num2str(m(:,21),12));
% d2un_i=bin2dec(num2str(m(:,18),12));
% d2_q=d2un_q-(d2un_q>=2^11)*2^12;
% d2_i=d2un_i-(d2un_i>=2^11)*2^12;
% d2_q=m(:,22);
% d2_i=m(:,21);
% rx_signal=d2_i+1i*d2_q;