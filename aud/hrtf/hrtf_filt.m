function [POUT, OUT]=hrtf_filt(Fin,d,Fwav,n,Fo)
% DESCRITPION:
%
%   Project a monochannel wave file into virtual auditory space using
%   subject specific HRTFs.  This is done by either using measured HRTFs or
%   interpolating HRTFs at intermediate points using a weighted average of
%   the closest neighbors.  see Jacobson et al. J Neurosci Methods (2001)
%   for a detailed description of how to estimate points at different
%   radii (not implemented here).  
%
% INPUT:
%
%   Fin:    string, full path to subject's HDS mat file. Fin can also be
%           the hds file itself.
%       hds is a structe containing the following fields.
%           .sub:   string, subject ID
%           .fs:    integer, sampling frequency
%           .thetaVec: double array, angles recorded.
%           .hrtf:  self explanatory
%           .hrir:  time representation of HRTF (ifft(hds.hrtf))
%   d:      double array, degree azimuth.  Note that d must be somewhere 
%           within the range of values in HDS. If undefined, defaults to
%           all measured angles.
%   Fwav:   string, full path to mono audio file to be convolved with HRTF.
%           Alternatively, Fwav can be a 1xN column matrix from
%           wavread(Fwav).  In the latter case, I will assume that the Fwav
%           sampling frequency is 96 kHz.  If this isn't the case, plan
%           accordingly or alter the code to fit your needs (should be very
%           easy to do.
%   n:      integer, number of samples to use in the HRIR (default=1:10000)
%   Fo:     string, base for output files.  If empty or not defined, output
%           files will not be written.
%
% OUTPUT:
%
%   OUT:    NxCxP double array, stimuli.
%   POUT:   Filenames of files written.
%   Wavefile written to subject's stimulus folder. (Only written if Fo
%   defined.)
%   
% 090311 CWB
%
%   -Changed interpolation/resample method to RESAMPLE instead of INTERP1.  
%   Sometimes interp1 returns a NaN for the last value when upsampling 
%   data. Resample handles this better.
%
%   -Also, after listening more carefully to unmeasured azimuth locations,
%   I don't think 5 degrees is a dense enough sampling.  I tried again with
%   a 1 degree spacing around the midline and this seemed to work well.  I
%   plan to take HRTFs every one degree (see Deas, Roach, and McGraw (2008)
%   for motivation).  I'm still convinced a weighted average will work for
%   spatial interpolation.
%
%
% Bishop, Chris Feb 2009

%% LOAD HRTF AND WAVEFILE 
% If Fin is a string, then assume it's a file name. Otherwise, assume it is
% the hds file itself.  Had to modify this when writing a batched call from
% hrtf_cal_prep.m.
% 'in' is now two channels. This was convenient for adding additional
% filters in the call to hrtf_cal_prep.m.
if ~isstr(Fin),hds=Fin;else, load(Fin,'hds');end
if ~isstr(Fwav),in=Fwav; FS=96000;else, [in,FS]=wavread(Fwav);end
if size(in,2)==1, in=[in in];end

%% CHECK INPUTS
if ~exist('n', 'var') || isempty(n), n=20000;end
if ~exist('d', 'var') || isempty(d), d=hds.thetaVec;end
POUT=[];
%% CREATE HRTF/HRIR FOR EACH LOCATION IN 'd'
for z=1:length(d)
    % First, check to see if the desired location was measured in the HRTF.  If
    % not, then interpolate position from two nearest neighbors.  Interpolation
    % is done by computing the weighted average of the two closest neighboring
    % HRTF measurements.  There are probably better ways of doing this 
    % (see Deas et al. 2008)
    out=[];
    ind=find(hds.thetaVec==d(z));
    if length(ind)>0
        HRTF=hds.hrtf(:,:,ind);
        HRIR=hds.hrir(:,:,ind);
    else
        ind=[max(find(hds.thetaVec<d(z))) min(find(hds.thetaVec>d(z)))];
        w(2)=(d(z)-hds.thetaVec(ind(1)))./(diff(hds.thetaVec(ind)));
        w(1)=1-w(2);
        HRTF=w(1).*hds.hrtf(:,:,ind(1))+w(2).*hds.hrtf(:,:,ind(2));
        HRIR=ifft(HRTF);
    end % if 

    % LIMIT HRIR LENGTH IF REQUESTED (define input 'n')
    HRIR=HRIR(1:n, :);

    %% FILTER WAVEFILE
    % First, see if the sampling rate matches between the HRTF and the
    % Wavefile.  If not, resample the wavefile to match the HRTF, then resample
    % to original FS.  Write file.  If sampling rates are not equal, HDS should
    % ALWAYS be higher (96 kHz on our system).
%     if hds.fs==FS
%         [out]=[fftfilt(HRIR(:,1),in(:,1)) fftfilt(HRIR(:,2),in(:,2))];
%     else
      % RESAMPLE AND FILTER EACH CHANNEL
      out(:,1)=resample(in(:,1),hds.fs, FS);
      out(:,2)=resample(in(:,2),hds.fs, FS);
      out=[fftfilt(HRIR(:,1),out(:,1)) fftfilt(HRIR(:,2),out(:,2))];
      out=resample(out,FS,hds.fs);
%     end % FS

    %% TRACK WAVEFILES: RETURNED TO USER.
    OUT(:,:,z)=out;
    
    %% WRITE FILE
    % Write the output to file if user specifies an output path.  
    if exist('Fo', 'var') && ~isempty(Fo)
        [PATHSTR,NAME,EXT,VERSN] = fileparts(Fo);    
        wavwrite(out,FS,[PATHSTR filesep NAME '_' num2str(d(z)) EXT VERSN]);
        POUT=strvcat(POUT, [PATHSTR filesep NAME '_' num2str(d(z)) EXT VERSN]);
    end % if exist(Fo)   
end % for z