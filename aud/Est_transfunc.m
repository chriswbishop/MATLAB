function [S2T, IRF, FLT, SOURCE, TARG]=Est_transfunc(SOURCE,TARG,FS,SPECS)
% DESCRIPTION:
%
%   Code to estimate the transfer function between two signals.  This will
%   return a transfer function (S2T) to convert the SOURCE to TARG.  Please
%   note that there the code deliberately delayes the auditory signal by 5
%   msec. So, any sound filtered using anything but filtfilt will be
%   delayed in time (linear phase shift) by 5 msec.  Please take this into
%   account in your code. 
%
% INPUT:
%
%   SOURCE:
%       Time waveform.  In the context of HRTFs, this is the source file
%       saved to the harddrive.  *NOTE* Remove zero padding from beginning
%       for proper temporal alignment.  If too much padding is present, the
%       5 msec padding added to TARG will be insufficient to create a
%       causal filter.  This leads to the IRF being "wrapped around" in
%       time.  If you can't remove the padding, increase the PAD variable
%       below to an appropriate value.
%
%   TARG:
%       Time waveform.  In the context of HRTFs, this is the recording.
%       Again, you should ideally remove any prepended zero padding from
%       the recording.
%
%   FS:
%       Integer, sampling rate (default 96 kHz)
%
%   SPECS:
%       Double array, specifications for bandpass filter.  
%           SPECS(1):   Lowest frequency in pass band (PFlow;default= 10Hz)
%           SPECS(2):   High frequency in pass band (PFhigh; default=25kHz)
%           SPECS(3):   Low stop frequency (SFlow; default=1Hz)
%                           Note: Don't set this to 0 Hz. The DC component
%                           will do funny things to your IR.
%           SPECS(4):   High stop frequency (SFhigh; default=30 kHz)
%
%       The bandpass filter is designed as follows:
%           Stop Band 1:            from 0 Hz to SBlow
%           Transition Band 1:      Blackman Window from SBlow:PFlow
%           Pass Band:              PFlow:PFhigh
%           Transition Band 2:      Blackman Window from PFhigh:SBhigh
%           Stop Band 2:            SBhigh:end
%
% OUTPUT:
%
%
% Bishop, Chris Miller Lab 2009

%% SET TIME DELAY
%   If your IRF is wrapped in time, first try removing zero padding from
%   both the SOURCE and TARG.  If this doesn't work, try extending PAD here
%   from 5 msec to something longer.
PAD=round(0.005 * FS);
T2S=[]; T2S_IRF=[];

%% INPUT CHECK
if ~exist('SPECS', 'var') || isempty(SPECS(1)), PFlow=20; end 
if ~exist('SPECS', 'var') || isempty(SPECS(2)), PFhigh=16000; end
if ~exist('SPECS', 'var') || isempty(SPECS(3)) || SPECS(3)==0, SFlow=0; end 
if ~exist('SPECS', 'var') || isempty(SPECS(4)), SFhigh=20000; end
if ~exist('FS', 'var') || isempty(FS), FS=96000; end

%% TEMPORALLY ALIGN SOURCE AND RECORDING
%   Assume that the recording will always be later in time than the SOURCE.
%   We have to put zeros at the beginning of the recording to make this a
%   causal filter.  The SOURCE and TARG are temporally offset by 0.5 msec.
%   This prevents the IRF from "wrapping around" in time.  The 0.5 msec
%   shift is arbitrary. 
SOURCE=detrend(SOURCE, 'constant');
TARG=detrend(TARG, 'constant');
if length(TARG)>length(SOURCE)
    [Y,I]=max(xcorr(SOURCE, TARG));
%     offset=size(TARG,1)-I-round(0.0005*FS);
    offset=size(TARG,1)-I-PAD;
    if offset>0
        TARG=[TARG(offset:end,:); zeros(offset-1,size(TARG,2))];
    else
        TARG=[zeros(abs(offset)-1,size(TARG,2)); TARG(abs(offset):end,:)];
    end
    TARG=[zeros(PAD,size(TARG,2)); TARG(1:size(SOURCE,1)-PAD)];
%     TARG=TARG(1:size(SOURCE,1));
elseif length(SOURCE)>length(TARG)
    [Y,I]=max(xcorr(TARG, SOURCE));
    offset=size(SOURCE,1)-I-PAD;
%     offset=size(SOURCE,1)-I-round(0.0005*FS);
    if offset>0
        SOURCE=[SOURCE(offset:end,:); zeros(offset-1,size(SOURCE,2))];
    else
        SOURCE=[zeros(abs(offset)-1,size(SOURCE,2)); SOURCE(abs(offset):end,:)];
    end
    SOURCE=SOURCE(1:size(TARG,1));
    TARG=[zeros(PAD,size(TARG,2)); TARG(1:end-PAD)];
end

%% CREATE BANDPASS FILTER
%   NyquistSamp:    Sample corresponding to Nyquist Frequency.
%   F:              Frequency bins
%   PFslow:         Sample corresponding to lowest frequency in pass-band
%   PFshigh:        Sample corresponding to highest frequency in pass-band
%   SFshigh:        Sample corresponding to first stop band frequency
%   SFslow:         Sample corresponding to second stop band frequency
%   FLT:            Pass band filter
%   
%   Transition bands (TB) are Blackman windowed to prevent spectral
%   leakage. The Pass Band (PB) is a vector of ones.  Stop Bands (SB) are
%   zeros. 
F = linspace(0,FS,length(TARG))';
NyquistSamp = length(F)/2;
PFslow=find(F(1:NyquistSamp)<=PFlow,1,'last');
PFshigh=find(F(1:NyquistSamp)>=PFhigh,1,'first');
SFslow=find(F(1:NyquistSamp)<=SFlow,1,'last');
SFshigh=find(F(1:NyquistSamp)>=SFhigh,1,'first');

SB1=zeros(SFslow-1,1);
% SB1=ones(SFslow-1,1).*0.000001;
% Changed so there aren't any infinite values (division by 0).
TB1=blackman((2*(PFslow-SFslow)+2));
% TB1=blackman((2*(PFslow-SFslow)+2)).*0.999999 + 0.000001;
PB=ones(PFshigh-PFslow-2,1); % subtract 2 to make room for the Blackman windows on either side.
TB2=blackman(2*(SFshigh-PFshigh)+2);
% TB2=blackman(2*(SFshigh-PFshigh)+2).*0.999999 + 0.000001;
SB2=zeros(NyquistSamp-SFshigh,1);
% SB2=ones(NyquistSamp-SFshigh,1).*0.000001;

FLT=[SB1; TB1(1:size(TB1,1)/2); PB; TB2(size(TB2,1)/2:end); SB2]; FLT=[FLT; flipud(FLT)];

%% ESTIMATE TRANSFER FUNCTION
%   Recall that in the frequency domain, SOURCE * TransFunc = TARG. Solving
%   for TransFunc is then trivial using TransFunc=TARG/SOURCE in the
%   frequency domain, which I believe is equivalent to deconvolution in the
%   time domain, but I've never tried the latter and don't care to.
S2T=(fft(TARG)./fft(SOURCE)).*(FLT*ones(1,size(TARG,2)));

%% IMPULSE RESPONSE ESTIMATION
IRF=ifft(S2T, 'symmetric');