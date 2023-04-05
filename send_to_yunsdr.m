function ret=send_to_yunsdr(txd,yunsdr_init)
if not(libisloaded('yunsdr_api'))
    addpath library
    [notfound,warnings] = loadlibrary('yunsdr_api','yunsdr_api.h');
end
dptr = libpointer('yunsdr_device_descriptor');
devstring = libpointer('cstring');
devstring.Value = yunsdr_init.ipaddr;
dptr = calllib('yunsdr_api', 'yunsdr_open_device', devstring);
if isNull(dptr)
    disp 'open yunsdr failed!';
    return;
end
%%  Configure RF IO
calllib('yunsdr_api', 'yunsdr_set_ref_clock', dptr, yunsdr_init.ref);
calllib('yunsdr_api', 'yunsdr_set_vco_select', dptr,  yunsdr_init.vco_cal);
calllib('yunsdr_api', 'yunsdr_set_trx_select', dptr, yunsdr_init.trx_sw);
calllib('yunsdr_api', 'yunsdr_set_duplex_select', dptr, yunsdr_init.fdd_tdd);
calllib('yunsdr_api', 'yunsdr_set_auxdac1', dptr, yunsdr_init.aux_dac1);
% calllib('yunsdr_api', 'yunsdr_set_adf4001', dptr, );
%%  Configure RF TX:
calllib('yunsdr_api', 'yunsdr_set_tx_lo_freq', dptr, yunsdr_init.freq);
calllib('yunsdr_api', 'yunsdr_set_tx_sampling_freq', dptr, yunsdr_init.samp);
calllib('yunsdr_api', 'yunsdr_set_tx_rf_bandwidth', dptr, yunsdr_init.bw);
calllib('yunsdr_api', 'yunsdr_set_tx_attenuation', dptr, 'TX1_CHANNEL', yunsdr_init.tx_att1);
calllib('yunsdr_api', 'yunsdr_set_tx_attenuation', dptr, 'TX2_CHANNEL', yunsdr_init.tx_att2);
pause(0.1);
%% txdata generation
% 16bit quantification
c1=max(max([abs(real(txd)),abs(imag(txd))]));
index=8000/c1;
txdata=round(txd.*index).*4;
% copy to 2chanel
if ~strcmp(yunsdr_init.tx_chan,'TX_DUALCHANNEL')
    txdata2=txdata;
else
    txdata2=zeros(1,size(txdata,1)*2);
    if size(txdata,2)==1
        txdata2(1:2:end)=txdata;
        txdata2(2:2:end)=txdata;
    else
        txdata2(1:2:end)=txdata(:,1);
        txdata2(2:2:end)=txdata(:,2);
    end
end
% iq mux
txdatas=zeros(1,length(txdata2)*2);
txdatas(1:2:end)=real(txdata2);
txdatas(2:2:end)=imag(txdata2);
% add pad
txdata1=[txdatas];% zeros(1,2000)
% to Byte
txd1=(txdata1<0)*65536+txdata1;
txd2=dec2hex(txd1,4);
txd3=txd2(:,1:2);
txd4=txd2(:,3:4);
txd5=hex2dec(txd3);
txd6=hex2dec(txd4);
txd7=zeros(length(txd6)*2,1);
txd7(1:2:end)=txd6;
txd7(2:2:end)=txd5;
%% generate tx frame buffer
tx_buf = libpointer('voidPtrPtr');
tx_buf.Value = libpointer('uint8Ptr', txd7);
%% reset timestamp
calllib('yunsdr_api', 'yunsdr_disable_timestamp', dptr);
calllib('yunsdr_api', 'yunsdr_enable_timestamp', dptr ,yunsdr_init.ppsmode);
%% read timestamp from yunsdr
timestamp = libpointer('uint64Ptr', 0);
calllib('yunsdr_api', 'yunsdr_read_timestamp', dptr, timestamp);
disp(['Now timestamp=',num2str(timestamp.value)]);
%% make gap
ticks = calllib('yunsdr_api', 'yunsdr_timeNsToTicks', yunsdr_init.txgap, yunsdr_init.samp);
disp(['tx frame gap=',num2str(yunsdr_init.txgap),'ns,(',num2str(ticks),'samples)']);
if strcmp(yunsdr_init.txmode,'START_TX_BURST')
    ticks=ticks+yunsdr_init.txgap;
else
    ticks=yunsdr_init.txgap;
end
%% txdata to yunsdr
calllib('yunsdr_api', 'yunsdr_enable_tx', dptr, size(txd,1), yunsdr_init.txmode);
nwrite = calllib('yunsdr_api', 'yunsdr_write_samples', dptr, tx_buf, length(txd7), yunsdr_init.tx_chan, ticks);
if nwrite < 0
    ret='data send to yunsdr fail';
	disp (ret);
    return
else
    ret='data send to yunsdr ok';
    disp(ret);
end