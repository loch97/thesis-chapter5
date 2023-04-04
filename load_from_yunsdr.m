function [rx_signal]= load_from_yunsdr(yunsdr_init)
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
%% generate rx frame buffer
if ~strcmp(yunsdr_init.rx_chan,'RX_DUALCHANNEL')
    NBYTE_PER_FRAME= yunsdr_init.rxsamples*4;
else
    NBYTE_PER_FRAME= yunsdr_init.rxsamples*2*4;
end
rx_buf = libpointer('voidPtrPtr');
rx_buf.Value = libpointer('uint8Ptr', zeros(1, NBYTE_PER_FRAME));
%% read timestamp from yunsdr
timestamp = libpointer('uint64Ptr', 0);
calllib('yunsdr_api', 'yunsdr_read_timestamp', dptr, timestamp);
%%  Configure RF RX:
calllib('yunsdr_api', 'yunsdr_set_rx_lo_freq', dptr, yunsdr_init.freq);
calllib('yunsdr_api', 'yunsdr_set_rx_rf_bandwidth', dptr, yunsdr_init.bw);
calllib('yunsdr_api', 'yunsdr_set_rx_gain_control_mode', dptr, 'RX1_CHANNEL', yunsdr_init.rxgain_mode1);
calllib('yunsdr_api', 'yunsdr_set_rx_gain_control_mode', dptr, 'RX2_CHANNEL', yunsdr_init.rxgain_mode2);
calllib('yunsdr_api', 'yunsdr_set_rx_rf_gain', dptr, 'RX1_CHANNEL', yunsdr_init.rxgain1);
calllib('yunsdr_api', 'yunsdr_set_rx_rf_gain', dptr, 'RX2_CHANNEL', yunsdr_init.rxgain2);
pause(0.5);
%% reset timestamp
if timestamp.value==0
    %%  Configure RF IO
    calllib('yunsdr_api', 'yunsdr_set_ref_clock', dptr, yunsdr_init.ref);
    calllib('yunsdr_api', 'yunsdr_set_vco_select', dptr,  yunsdr_init.vco_cal);
    calllib('yunsdr_api', 'yunsdr_set_trx_select', dptr, yunsdr_init.trx_sw);
    calllib('yunsdr_api', 'yunsdr_set_duplex_slect', dptr, yunsdr_init.fdd_tdd);
    calllib('yunsdr_api', 'yunsdr_set_auxdac1', dptr, yunsdr_init.aux_dac1);
    % calllib('yunsdr_api', 'yunsdr_set_adf4001', dptr, );
    %%  Configure RF RX:  
    calllib('yunsdr_api', 'yunsdr_set_rx_sampling_freq', dptr, yunsdr_init.samp);
    %%  restart timestamp
    pause(0.5);
    calllib('yunsdr_api', 'yunsdr_disable_timestamp', dptr);
    calllib('yunsdr_api', 'yunsdr_enable_timestamp', dptr ,yunsdr_init.ppsmode);
end
%% configure rx mode
calllib('yunsdr_api', 'yunsdr_enable_rx', dptr, yunsdr_init.rxsamples, yunsdr_init.rx_chan,yunsdr_init.rxmode, 0);
%% read timestamp and set a timestamp to receive data
timestamp=0;
%% receive data
rx_timeout = 6.5; %in seconds
nread = calllib('yunsdr_api', 'yunsdr_read_samples', dptr, rx_buf, uint32(NBYTE_PER_FRAME), timestamp, rx_timeout);
if nread < 0
    disp ('rx error!');
end
%% stop tx loop mode
% calllib('yunsdr_api', 'yunsdr_enable_tx', dptr, NSAMPLES_PER_FRAME, 'STOP_TX_LOOP');
%% data 8bit to 16bit 
datah=rx_buf.Value(2:2:end);
datal=rx_buf.Value(1:2:end);
datah_hex=dec2hex(datah,2);
datal_hex=dec2hex(datal,2);
data_hex(:,1:2)=datah_hex;
data_hex(:,3:4)=datal_hex;
dataun=hex2dec(data_hex);
datain=dataun-(dataun>32767)*65536;
if strcmp(yunsdr_init.rx_chan, 'RX_DUALCHANNEL')
    a1=datain(1:4:end);
    a2=datain(2:4:end);
    a3=datain(3:4:end);
    a4=datain(4:4:end);
    rx_signal(:,1)=(a1+1i*a2);
    rx_signal(:,2)=(a3+1i*a4);
else
    a1=datain(1:2:end);
    a2=datain(2:2:end);
    rx_signal(:,1)=(a1+1i*a2);
end