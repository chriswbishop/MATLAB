function portaudio_adaptiveplay(X, varargin)
%% DESCRIPTION:
%
%   This function is designed to allow (near) real-time modification of
%   sound playback. To do this, the function will accept a function handle
%   to a "checker" function that determins whether or not a change in the
%   audio is required. The function will also accept a "modifier" function
%   that modifies the time series during sound playback. 
%
%   This function (the top-level function) will then handle the transition
%   from one sound state to the next. 
%
% INPUT:
%
%   X:  
%
% Parameters:
%
%   'bock_dur':     data block size in seconds. The shorter it is, the
%                   faster the adaptive loop is. The longer it is, the less
%                   likely you are to run into buffering problems. 
%
%   'modcheck': function handle. This class of functions determines whether
%               or not a modification is necessary. At the time he wrote
%               this, CWB could imagine circumstances in which the same
%               modifier must be applied, but under various conditions. By
%               separating the functionality of 'modcheck' and 'modifier',
%               the user can create any combination. This should, in
%               theory, improve the versatility of the adaptive playback
%               system. 
%
%               'modcheck' can perform any type of check, but must be self
%               contained. Meaning, it (typically) cannot rely exclusively
%               on information present in the adaptive play control loop.
%               An example of a modcheck might go something like this.
%
%                   1. On the first call, create a keyboard queue to
%                   monitor for specific button presses.
%
%                   2. On subsequent calls, check the queue and determine
%                   if a specific button (or combination thereof) was
%                   pressed.
%
%                   3. If some preexisting conditions are met, then modify
%                   the signal. Otherwise, do not modify the signal.
%
%               Alternatively, a modcheck might do the following.
%
%                   1. On the first call, open a GUI with callback buttons
%                   for users to click on. 
%
%                   2. On successive calls, check to see if a button has
%                   been clicked. If it has, then return a modification
%                   code.
%
%               'modchecks' must accept a single input; a structure with
%               whatever information successive calls to the modcheck will
%               need (e.g., figure handles, etc.). 
%
%               modchecks must return the following variables
%                   
%                   1. needmod: bool, determines whether or not a
%                   modification is necessary at all.
%           
%                   2. mod_code:    integer (typically) describing the
%                                   nature of the required modification.
%                                   This code is further interpreted by
%                                   the modifier (below).
%
%                   3. c:   a structure containing additional information
%                           that may be necessary for successive calls to
%                           'modcheck'.
%
%   'modifier': function handle. This class of functions will modify the
%               output signal X when the conditions of 'modcheck' (see
%               above) are satisfied. The function can do just about
%               anything, but must conform to some general guidelines.
%
%                   1. The function must accept three inputs
%
%                           X:  the time series to alter
%
%                           mod_code:   a modification code. This will
%                                       prove useful when one of several
%                                       conditional modifications are
%                                       possible (e.g., making a sound
%                                       louder or quieter). 
%
%                           m:  a structure with other information
%                               generated by a previous call to the
%                               modifier.
%
%                   2. The function must have three outputs
%
%                           Y:  the modified time series X
%
%                           m:  the updated modifier structure. This will
%                               be provided as an input during all
%                               subsequent calls to the modifier.
%
%                           term:   bool, whether or not to termination the
%                                   adaptive playback. (true = terminate |
%                                   false = continue playback)
%
%   'adaptive_mode':    string, describing how the modifications should be
%                       applied to the data stream. This is still under
%                       development, but different tests (e.g., HINT and
%                       ANL) need the modifications to occur on different
%                       timescales (between words or during a continuous
%                       playback stream). The hope here is to include
%                       various adaptive modes to accomodate these needs.
%
%                           'realtime': apply modifications in as close to
%                                       real time as possible. This will
%                                       depend heavily on the size on the
%                                       'block_dur' parameter above; the
%                                       longer the block_dur, the longer it
%                                       takes for the "real time" changes
%                                       to take effect. But if the
%                                       block_dur is too short, then you
%                                       run into other, irrecoverable
%                                       problems (like buffer underruns).
%                                       Choose your poison. 
%
%                           'byfile':      apply modifications at the end 
%                                           of each playback file. (under
%                                           development). This mode was
%                                           intended to accomodate the 
%                                           HINT.       
%
%   'append_files':     bool, append data files into a single file. This
%                       might be useful if the user wants to play an
%                       uninterrupted stream of files and the timing
%                       between trials is important. (true | false;
%                       default=false);
%
%                       Note: Appending files might pose some problems for
%                       established modchecks and modifiers (e.g., for
%                       HINT). Use this option with caution. 
%
%   'stop_if_error':    bool, aborts playback if there's an error. At tiem
%                       of writing, this only includes a check of the
%                       'TimeFailed' field of the playback device status.
%                       But, this can be easily expanded to incorporate all
%                       kinds of error checks. (true | false; default=true)
%
%                       Note: at time of writing, error checking only
%                       applies to 'realtime' adaptive playback. 
%
%                       Note: the 'TimeFailed' field does not increment for
%                       buffer underruns. Jeez. 
%
%                       Note: The 'XRuns' field also does not reflect the
%                       number of underruns. E-mailed support group on
%                       5/7/2014. We'll see what they say. 
%
% Windowing options (for 'realtime' playback only):
%
%   In 'realtime' mode, data are frequently ramped off or on (that is, fade
%   out or fade in) to create seamless transitions. These paramters allow
%   the user to specify windowing options, including a windowing function
%   (provided it's supported by matlab's "window" function) and a ramp
%   time.
%
%       'window_fhandle':function handle to windowing function. (default =
%                       @hann). See window.m for more options. 
%
%       'window_dur':   duration of windowing function. Too short may lead
%                       to popping or clicking in playback. Too long and
%                       it takes longer for adpative changes to occur
%                       (longer before the change "fades in"). 
%                       (seconds | default = 0.005 (5 msec))
%
% OUTPUT:
%
%   XXX
%
% Development:
%
%   1. Add timing checks to make sure we have enough time to do everything
%   we need before the buffer runs out
%
%   3. Add options for handling buffer underruns. These should generally
%   throw an irrecoverable error lest our acoustic control deteriorate, but
%   there may be circumstances in which the user wants to ignore these
%   warnings and move despite any potential problems. 
%
%   4. Add continuously looped playback (priority 1). 
%
%   8. Load defaults in a smarter way. Right now hard-coded to load ANL
%   parameters, but CWB has plans to use this for HINT and other tests.
%
%   10. Add ability to independently control multiple channels (e.g.,
%   adaptive changes for each channel separately). Or, alternatively, allow
%   user to select which channels to apply adaptive changes to rather than
%   the whole time series and all channels wholesale. Might be worth adding
%   this to the modifier function ... not sure. Needs more thought. 
%       - Add flag for independent modification. 
%       - Or, add an integer channel array specifiying which channels to
%       apply which modifiers to. This would need to be a cell array. Still
%       needs more thinking. ...
%
%   11. Allow option inputs for c/m (modcheck and modifier data
%   structures). Might be useful if users need to set initialization
%   parameters. 
%
% Christopher W. Bishop
%   University of Washington
%   5/14

%% MASSAGE INPUT ARGS
% Convert inputs to structure
%   Users may also pass a parameter structure directly, which makes CWB's
%   life a lot easier. 
if length(varargin)>1
    p=struct(varargin{:}); 
elseif length(varargin)==1
    p=varargin{1};
elseif isempty(varargin)
    p=struct();     
end %

%% INPUT CHECK AND DEFAULTS
%   Load defaults from SIN_defaults, then overwrite these by user specific
%   inputs. 
defs=SIN_defaults; 
d=defs.hint; 
FS=d.fs; 
% FS=22050; 

%% FUNCTION SPECIFIC DEFAULTS
%   - Use a Hanning windowing function by default
%   - Use 5 ms ramp time
%   - Do not append files by default 
%   - Abort if we encounter issues with the sound playback buffer. 
if ~isfield(d, 'window_fhandle') || isempty(d.window_fhandle), d.window_fhandle=@hann; end
if ~isfield(d, 'window_dur') || isempty(d.window_dur), d.window_dur=0.005; end 
if ~isfield(d, 'append_files') || isempty(d.append_files), d.append_files=false; end 
if ~isfield(d, 'stop_if_error') || isempty(d.stop_if_error), d.stop_if_error=true; end 

% Save file names
file_list=X; 
clear X; 

% OVERWRITE DEFAULTS
%   Overwrite defaults if user specifies something different.
flds=fieldnames(p);
for i=1:length(flds)
    d.(flds{i})=p.(flds{i}); 
end % i=1:length(flds)

% Clear p
%   Only want to use d for consistency and to minimize errors. So clear 'p'
%   to remove temptation.
clear p; 

%% INTIALIZE MODCHECK AND MODIFIER STRUCTS
%   Need to provide option settings for user input, so intialization
%   parameters can be changed if necessary. 
m=struct(); % modifier struct
c=struct(); % modcheck struct

%% LOAD DATA
%   1. Support only wav files. 
%       - Things break if we accept single/double data series with variable
%       lengths (can't append data types easily using AA_loaddata). So,
%       just force the user to supply wav files. That should be fine. 
%
%   2. Resample data to match the output sample rate. 
%
% Note: We want to load all the data ahead of time to minimize
% computational load during adaptive playback below. Hence why we load data
% here instead of within the loop below. 
t.datatype=2;

% Store time series in cell array (stim)
stim=cell(length(file_list),1); % preallocate for speed.
for i=1:length(file_list)
    [tstim, fsx]=AA_loaddata(file_list{i}, t);
    stim{i}=resample(tstim, FS, fsx); 
    
    % Playback channel check
    %   Confirm that the number of playback channels corresponds to the
    %   number of columns in stim{i}
    if numel(d.playback_channels) ~= size(stim{i},2)
        error(['Incorrect number of playback channels specified for file ' file_list{i}]); 
    end % if numel(p.playback_channels) ...
    
end % for i=1:length(file_list)

clear tstim fsx;

% Add file_list to d structure
d.file_list=file_list; 

% Append playback files if flag is set
if d.append_files
    
    tstim=[];
    
    for i=1:length(stim)
        tstim=[tstim; stim{i}];
    end % for i=1:length(stim)
    
    clear stim;
    stim{1}=tstim; 
    clear tstim
    
end % if d.append_files

%% LOAD PLAYBACK AND RECORDING DEVICES
%   Get these from SIN_defaults as well. 
InitializePsychSound; 

% Get playback device information 
[pstruct]=portaudio_GetDevice(defs.playback.device);

% Open the playback device 
%   Only open audio device if 'realtime' selected. Otherwise, device
%   opening/closing is handled through portaudio_playrec.
if isequal(d.adaptive_mode, 'realtime')
    phand = PsychPortAudio('Open', pstruct.DeviceIndex, 1, 0, FS, pstruct.NrOutputChannels);
end % if isequal(d.adaptive_mode ...

%% BUFFER INFORMATION
%   This information is only used in 'realtime' adaptive playback. Moved
%   here rather than below to minimize overhead (below this would be called
%   repeatedly, but these values do not change over stimuli). 

% Create empty playback buffer
buffer_nsamps=round(d.block_dur*FS)*2; % need 2 x the buffer duration

% block_nsamps
%   This prooved useful in the indexing below. CWB opted to use a two block
%   buffer for playback because it's the easiest to code and work with at
%   the moment. 
block_nsamps=buffer_nsamps/2; 

% Find beginning of each "block" within the buffer
block_start=[1 block_nsamps+1];

% Creat global trial variable. This information is often needed for
% modification check and modifier functions. So, just make it available
% globally and let them tap it if necessary. 
global trial

%% INITIALIZE MODCHECK and MODIFIER
%   These functions often have substantial overhead on their first call, so
%   they need to be primed (e.g., if a figure must be generated or a sound
%   device initialized).

% Call modcheck
[mod_code, c]=d.modcheck.fhandle(d);      

% Call modifier
%   Call with empty data
[~, m]=d.modifier.fhandle([], mod_code, d); 

for trial=1:length(stim)
    
    %% SELECT APPROPRIATE STIMULUS
    X=stim{trial}; 
    
    %% FILL X TO MATCH NUMBER OF CHANNELS
    %   Create a matrix of zeros, then copy X over into the appropriate
    %   channels. CWB prefers this to leaving it up to psychportaudio to
    %   select the correct playback channels. 
    x=zeros(size(X,1), pstruct.NrOutputChannels);
    
    x(:, d.playback_channels)=X; % copy data over into playback channels
    X=x; % reassign X

    % Clear temporary variable x 
    clear x; 

    %% CREATE WINDOWING FUNCTION (ramp on/off)
    %   This is used for realtime adaptive mode. The windowing function can
    %   be provided by the user, but it must be a function handle accepted
    %   by MATLAB's window function.    
    win=window(d.window_fhandle, round(d.window_dur*2*FS)); % Create onset/offset ramp

    % Match number of channels
    win=win*ones(1, size(X,2)); 

    % Create ramp_on (for fading in) and ramp_off (for fading out)
    ramp_on=win(1:ceil(length(win)/2),:); ramp_on=[ramp_on; ones(block_nsamps - size(ramp_on,1), size(ramp_on,2))];
    ramp_off=win(ceil(length(win)/2):end,:); ramp_off=[ramp_off; zeros(block_nsamps - size(ramp_off,1), size(ramp_off,2))];    

       
    % Switch to determine mode of adaptive playback. 
    switch lower(d.adaptive_mode)
        case {'realtime'}   
            
            % nblocks
            %   Variable only used by 'realtime' plaback
            nblocks=ceil(size(X,1)./size(ramp_on,1)); 
            
            % Loop through each section of the playback loop. 
            for i=1:nblocks
                tic
                % Which buffer block are we filling?
                %   Find start and end of the block
                startofblock=block_start(1+mod(i-1,2));
    
                % Find data we want to load 
                if i==nblocks
                    % Load with the remainder of X, then pad zeros.         
                    data=[X(1+block_nsamps*(i-1):end, :); zeros(block_nsamps - size(X(1+block_nsamps*(i-1):end, :),1), size(X,2))];
                else
                    data=X(1+block_nsamps*(i-1):(block_nsamps)*i,:);
                end 
    
                % Check if modification necessary
                [mod_code, c]=d.modcheck.fhandle(c); 
        
                % Save upcoming data
                x=data.*ramp_off;
        
                % Modify main data stream
                [X, m]=d.modifier.fhandle(X, mod_code, m); 
        
                % Grab data from modified signal
                if i==nblocks
                    % Load with the remainder of X, then pad zeros.         
                    data=[X(1+block_nsamps*(i-1):end, :); zeros(block_nsamps - size(X(1+block_nsamps*(i-1):end, :),1), size(X,2))];
                else
                    data=X(1+block_nsamps*(i-1):(block_nsamps)*i,:);
                end % if 
        
                % Ramp new stream up, mix with old stream. 
                %   - The mixed signal is what's played back. 
                %   - We don't want to ramp the first block in, since the
                %   ramp is only intended to fade on block into the next in
                %   a clean way. 
                if i==1
                    data=data + x;
                else
                    data=data.*ramp_on + x; 
                end % if i==1
    
                % Basic clipping check
                if max(max(abs(data))) > 1, error('Signal clipped!'); end 
                    
                % First time through, we need to start playback
                %   This has to be done ahead of time since this defines
                %   the buffer size for the audio device. 
                if i==1
                    % Start audio playback, but do not advance until the device has really
                    % started. Should help compensate for intialization time. 
        
                    % Fill buffer with zeros
                    PsychPortAudio('FillBuffer', phand, zeros(buffer_nsamps,size(data,2))'); 
                    PsychPortAudio('Start', phand, ceil(nblocks/2), [], 1);                    
                    
                    % Wait until we are in the second block of the buffer,
                    % then start rewriting the first. Helps with smooth
                    % starts 
                    pstatus=PsychPortAudio('GetStatus', phand); 
                    while mod(pstatus.ElapsedOutSamples, buffer_nsamps) - block_start(2) < buffer_nsamps/4 % start updating sooner.  
                        pstatus=PsychPortAudio('GetStatus', phand); 
                    end % while
                    
                end % if i==1               
    
                % Fill playback buffer in different ways. First time 
                % through, fill the buffer directly, all other times, just
                % append the data for the next section. 
                %
                % Start playback, but only after the first samples are
                % loaded into the buffer.                                
                if false
                    PsychPortAudio('FillBuffer', phand, data', 0, []);
                else
                    % Load data into playback buffer
                    %   CWB tried specifying the start location (last parameter), but he
                    %   encountered countless buffer underrun errors. Replacing the start
                    %   location with [] forces the data to be "appended" to the end of the
                    %   buffer. For whatever reason, this is far more robust and CWB
                    %   encountered 0 buffer underrun errors.                 
                    PsychPortAudio('FillBuffer', phand, data', 1, []);  
                end % if i==1                
                
                toc

                pstatus=PsychPortAudio('GetStatus', phand);
                
                % Now, loop until we're half way through the samples in 
                % this particular buffer block.
                while mod(pstatus.ElapsedOutSamples, buffer_nsamps) - startofblock < buffer_nsamps/4 ... 
                        && i<nblocks % additional check here, we don't need to be as careful for the last block
                    pstatus=PsychPortAudio('GetStatus', phand); 
                end % while
                
                % Error checking after each loop
                if d.stop_if_error && (pstatus.XRuns >0 || pstatus.TimeFailed >0)
                    PsychPortAudio('Stop', phand); 
                    error('Error during sound playback. Check buffer_dur.'); 
                end % if d.stop ....
                
            end % for i=1:nblocks
            
            % Schedule stop of playback device.
            %   Should wait for scheduled sound to complete playback. 
            PsychPortAudio('Stop', phand, 1); 
            
        case {'byfile'}
        
            % 'byseries' was initially intended to administer the HINT. 
        
            % Call modifier information first, in case there are initial
            % conditions (like scaling sounds relative to one another) that
            % must be taken care of. 
        
            % Sound playback
            portaudio_playrec([], pstruct, X, FS, 'fsx', FS);
            
            % Call modcheck        
            [mod_code, c]=d.modcheck.fhandle(c); 
        
            % Modify all time series        
            [X, m]=d.modifier.fhandle(X, mod_code, m); 
        
        otherwise
            error(['Unknown adaptive mode (' d.adaptive_mode '). See ''''adaptive_mode''''.']); 
    end % switch d.adaptive_mode

end % for trial=1:length(X)

% Close all open audio devices
PsychPortAudio('Close')