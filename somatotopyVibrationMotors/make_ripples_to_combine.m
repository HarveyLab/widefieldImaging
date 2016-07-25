
%% Sum carriers, in a for-loop
% snd   = 0;
durrip   = 2000; %msec
Fs    = 192000; % sample frequency (Hz)
nRip    = round( (durrip/1000)*Fs ); % # Samples for Rippled Noise
time  = ((1:nRip)-1)/Fs; % Time (sec)
N     = 512; % # components

F0      = 250; % base frequency (Hz)
nFreq   = 512; % (octaves)
FreqNr  = 0:1:nFreq-1; % every frequency step
Freq    = F0 * 2.^(FreqNr/50); % frequency vector (Hz)
freq_step = 80;
Freq = F0+FreqNr.*freq_step;
% vel = zeros(size(time));

velocities = [4:4:24];
densities = [-1.5:.5:1.5];
for v = 1:length(velocities)
    for d = 1:length(densities);
        disp('tic')
        snd = zeros(size(time));
        
        snd   = snd/N;
        vel = velocities(v);
        dens = densities(d);
        % vel   = 4; % omgea (Hz)
        %         dens   = 1; % Omega (cyc/oct)
        mod   = 100; % Percentage (0-100%)
        
        Oct     = FreqNr/20;
        nTime = length(time);
        % octaves above the ground frequency
        oct    = repmat(Oct',1,nTime); % Octave
        
        
        
        %% Create amplitude modulations completely dynamic in a loop
        A = NaN(nTime,nFreq); % always initialize a matrix
        for ii = 1:nTime
            for jj = 1:nFreq
                A(ii,jj)      = 1 + mod*sin(2*pi*vel*time(ii) + 2*pi*dens*oct(jj));
            end
        end
        
        
        % % Modulate carrier, in a for-loop
        % snd = 0;
        for ii = 1:nFreq
            phi     = 2*pi*rand(1); % random phase between 0-2pi
            carr      = A(:,ii)'.*sin(2*pi* Freq(ii) .* time + phi);
            % carr      = A(:,ii)'.*sin(2*pi* Freq(ii) .* time);
            snd        = snd+carr;
        end
        ripple(v,d,:) = snd;
    end
    
end