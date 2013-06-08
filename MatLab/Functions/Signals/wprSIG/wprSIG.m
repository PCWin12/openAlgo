function [s,r,sh,w,thresh] = wprSIG(price,N,thresh,scaling,cost,bigPoint)
%WPRSIG WPR signal generator from 'willpctr.m' function by The MathWorks, Inc.
% WPRSIG trading strategy.  Note that the trading signal is generated when the
% WPR value is above/below the upper/lower threshold.  
% N serves as an optional lookback period (default 14 observations)
%
%   NOTE: It is important to consider that a WPR signal generator really has 3 states.
%           Above Threshold is Overbought
%           Below Threshold is Oversold
%           There is also a neutral region between +/- Threshold and 50%
%
%   This should be considered prior to adding or removing any Echos to this output.
%   For calculating a direct PNL, the signal should first be cleaned with remEcho_mex.
%
%   INPUTS:
%           price       an array of any [C] or [O | C] or [O | H | L | C]
%           N           observation lookback period
%           thresh      threshold of overbought / oversold (X | [X 100-X] is submitted)
%           scaling     sharpe ratio adjuster
%           cost        round turn commission cost for proper P&L calculation
%           bigPoint    Full tick dollar value of security
%   OUTPUTS:
%           s           The generated output SIGNAL
%           r           Return generated by the derived signal
%           sh          Sharpe ratio generated by the derived signal
%           w           WPR values generated by the call to 'willpctr.m'
%           thresh      Echos the input threshold value (primarily for debugging)
%
% Author:           Mark Tompkins
% Revision:			4906.29471
% All rights reserved.

%% MEX code to be skipped
coder.extrinsic('OHLCSplitter','willpctr','remEchos_mex','calcProfitLoss','sharpe')

% WPR works with negative values in a range from 0 to -100;
if numel(thresh) == 1 % scalar value
    thresh = [(100-abs(thresh))*-1, abs(thresh)*-1];
else
    thresh = abs(thresh)*-1;
end;
if thresh(1) < thresh(2)
    thresh= thresh(2:-1:1);
end;

if thresh(1) > 0, thresh(1) = thresh(1) * -1; end;
if thresh(2) > 0, thresh(2) = thresh(2) * -1; end;

% Preallocate so we can MEX
rows = size(price,1);
fOpen = zeros(rows,1);                                      %#ok<NASGU>
fClose = zeros(rows,1);                                     %#ok<NASGU>
fHigh = zeros(rows,1);                                      %#ok<NASGU>
fLow = zeros(rows,1);                                       %#ok<NASGU>
s = zeros(rows,1);
w = zeros(rows,1);                                          %#ok<NASGU>

if size(price,2) == 4
    [fOpen, fHigh, fLow, fClose] = OHLCSplitter(price);
else
    error('wprMETS:InputArg',...
    	'We need as input O | H | L | C.');
end; %if

%% williams %r
w = willpctr([fHigh fLow fClose],N);

%% generate signal
% Crossing the upper threshold (overbought)
indx = w > thresh(1);
s(indx) = -1.5;

indx = w < thresh(2);
s(indx) = 1.5;

if ~isempty(find(s,1))
    % Clean up repeating information so we can calculate a PNL
	s = remEchos_mex(s);
    
    %% PNL Caclulation
    [~,~,~,r] = calcProfitLoss([fOpen fClose],s,bigPoint,cost);
	sh = scaling*sharpe(r,0);
else
    % No signal - no return or sharpe
    r = zeros(length(fClose),1);
	sh = 0;
end; %if