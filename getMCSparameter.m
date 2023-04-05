function [codeRate,modOrder,name] = getMCSparameter(cfg)
    switch cfg.MCS
        case 0
            codeRate = '1/2';
            modOrder = 1;
            name = 'BPSK';
        case 1
            codeRate = '1/2';
            modOrder = 2;
            name = 'QPSK';
        case 2
            codeRate = '3/4';
            modOrder = 2;
            name = 'QPSK';
        case 3
            codeRate = '1/2';
            modOrder = 4;
            name = '16QAM';
        case 4
            codeRate = '3/4';
            modOrder = 4;
            name = '16QAM';
        case 5
            codeRate = '2/3';
            modOrder = 6;
            name = '64QAM';
        case 6
            codeRate = '3/4';
            modOrder = 6;
            name = '64QAM';
        case 7
            codeRate = '5/6';
            modOrder = 6;
            name = '64QAM';
        case 8
            codeRate = '3/4';
            modOrder = 8;
            name = '256QAM';
        case 9
            codeRate = '5/6';
            modOrder = 8;
            name = '256QAM';
        case 10
            codeRate = '3/4';
            modOrder = 10;
            name = '1024QAM';
        case 11
            codeRate = '5/6';
            modOrder = 10;
            name = '1024QAM';
    end
end

