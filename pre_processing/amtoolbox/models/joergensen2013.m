function output = joergensen2013(x,y,fs_input,IO_param)
%JOERGENSEN2013  Speech-based envelope power spectrum (multi-resolution EPSM)
%   Usage: output = joergensen2013(x, y, fs, IO_param)
%
%   Input parameters:
%
%     x        : noisy speech mixture 
%     y        : noise alone
%     fs       : sample rate in Hz
%     IO_param : (optional) vector with parameters for the ideal observer 
%                that converts the SNRenv to probability of correct, assuming a
%                given speech material. It contains four parameters of the ideal observer 
%                formatted as [k q m sigma_s].
%
%   Output parameters:
%
%     output.SNRenv:     The SNRenv
%     output.P_correct:  The probability of correct given the
%                        SNRenv. This field is only included if IO_param is specified.
%                        Its calculation requires the Statistics ToolBox. 
%
%   output = JOERGENSEN2013(x, y, fs, IO_param) calculates the 
%   signal-to-noise envelope-power (SNRenv) ratio using the 
%   multi-resolution speech-based envelope spectrum model (mr-sEPSM)
%   described in Joergensen et al. (2013).
%   The main difference between to the Joergensen et al. (2011) 
%   model is that the present model estimates the envelope power
%   using multi-resolution segmentation of the envelope. The segment
%   duration depends on the modulation filter center-frequency. In addition,
%   the modulation filter bank includes filters up to modulation frequencies
%   of 256 Hz in contrast to the 64 Hz considered by the model from
%   Joergensen et al. (2011).
%
%   The model is based on the model from Joergensen et al. (2011), which consists of the following stages:
%
%   1 A gammatone bandpass filterbank to simulate the auditory filters
%
%   2 An envelope extraction stage via the Hilbert Transform
%
%   3 A modulation filterbank
%  
%   4 Computation of the long-term envelope power (*output.SNRenv*)
%
%   5 A decision mechanism based on a statistically ideal observer (*output.P_correct*)
%
%
%   See also: sig_joergensen2011 plot_joergensen2013 demo_joergensen2013
%             joergensen2013_sim joergensen2011 relanoiborra2019
%
%   References:
%     S. Joergensen and T. Dau. Predicting speech intelligibility based on
%     the signal-to-noise envelope power ratio after modulation-frequency
%     selective processing. J. Acoust. Soc. Am., 130(3):1475--1487, 2011.
%     
%     S. Jørgensen, S. D. Ewert, and T. Dau. A multi-resolution envelope
%     power based model for speech intelligibility. J. Acoust. Soc. Am.,
%     134(1):436--446, 2013.
%     
%
%   Url: http://amtoolbox.org/amt-1.1.0/doc/models/joergensen2013.php

% Copyright (C) 2009-2021 Piotr Majdak, Clara Hollomey, and the AMT team.
% This file is part of Auditory Modeling Toolbox (AMT) version 1.1.0
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

%   #StatusDoc: Submitted
%   #StatusCode: Submitted
%   #Verification: Untrusted
%   #Requirements: MATLAB M-Signal M-Stats

if nargin < 3
    error('Too few input arguments.');
end

if length(x)~=length(y)
    error('x and y should have the same length');
end

% initialization
x           = x(:)';                             % Noisy speech row vector
y           = y(:)';                             % Noise alone speech row vector
fs          = 22050;
cf_aud = [63    80   100  125  160  200    250    315  400   500  630 800  1000  1250  1600  2000 2500 3150 4000 5000 6300  8000]; % centerfrequencies of the gammatone filters
cf_mod = [1 2 4 8 16 32 64 128 256];% centerfrequencies of the modulation filters
HT_diffuse = [37.5 31.5  26.5  22.1 17.9 14.4 11.4 8.4 5.8  3.8  2.1  1.0  0.8  1.9  0.5 -1.5 -3.1 -4.0 -3.8 -1.8 2.5   6.8 ]; % Diffuse field hearing threshold in quiet: ISO 389-7:2005


if fs_input ~= fs
    x	= resample(x, fs, fs_input);
    y 	= resample(y, fs, fs_input);
end

N = length(x);
%% Filtering through gammatone filterbank
g = gammatonefir(cf_aud,fs,'complex');
X  = 2*real(ufilterbank(x,g,1));
Y  = 2*real(ufilterbank(y,g,1));

%% ------------------ determining which frequency bands that are above
%% the hearing threshold.
% The spectrum levels (in SPL) of the stimuli are determined from a 1/3-octave analysis, since the threshold to compare with
% is spectrum levels.

mix_rms = thirdOctRMSAnalysis(x,fs,cf_aud);
mixRMS_dB =  20*log10(mix_rms);
bands = find(mixRMS_dB>HT_diffuse(1:length(cf_aud))); %     The bands to process further are the bands where the mix has spectrum levels above the hearing threshold.

%% ------------------ calculating envelopes of temporal outputs
%  lowpass filtering at 150 Hz
[bb, aa] = butter(1, 150*2/fs);

x_env = zeros(N,length(cf_aud));
y_env = zeros(N,length(cf_aud));

x_env(:,bands) = abs(hilbert(X(:,bands))); %  envelope
y_env(:,bands) = abs(hilbert(Y(:,bands)));

x_env = filter(bb,aa,x_env);
y_env = filter(bb,aa,y_env);

%downsampling
D = 10;
fsNew = fs/D;

x_env = resample(x_env,fsNew,fs);
y_env = resample(y_env,fsNew,fs);
%
SNRenv_n_p = zeros(length(cf_mod),length(cf_aud));


for p = bands% For every audio channel
    
    %% ----------------- Analysis via modulation filterbank
    
    xx(:,:,p)  = modFbank_v3(x_env(:,p),fsNew,cf_mod);
    yy(:,:,p)  = modFbank_v3(y_env(:,p),fsNew,cf_mod);
    
    N_xx = size(xx,2);
    WinDurs = 1./cf_mod; %The window duration is the inverse of the centerfrequency of the modulation channel
    
    WinLengths = floor(WinDurs * fsNew);
    Nsegments = floor(N_xx./WinLengths)+ ones(1,length(cf_mod));%       The total number of segments is Nframes plus any additional "leftover"
    
    P_env_xx = zeros(Nsegments(end),length(cf_mod),length(cf_aud));
    P_env_yy = P_env_xx;
    
    if find(WinLengths == N_xx)% If the duration of the stimulus is exactly equalt to the window duration
        segIdx = find(WinLengths == N_xx);
        Nsegments(segIdx) =  Nsegments(segIdx)-1;
    end
    
    DC_power_x = (mean(x_env(:,p)).^2) /2;
    DC_power_y = (mean(y_env(:,p)).^2) /2;
    
    
    for n = 1:length(cf_mod) %For each modulation channel
        %         Initialize temporary variables:
        tmp_xx = zeros(WinLengths(n),Nsegments(n));
        tmp_yy = tmp_xx;
        segLengths = zeros(1,Nsegments(n)) ;
        
        for i = 1:Nsegments(n) %For each temoral segment of the signal
            %              find the start and end index of the frame
            if i > (Nsegments(n)-1)
                startIdx = 1 + (i-1)*WinLengths(n);
                endIdx = N_xx;
            else
                startIdx = 1 + (i-1)*WinLengths(n);
                endIdx = startIdx + WinLengths(n)-1;
            end
            segment = startIdx:endIdx;
            segLengths(i) = length(segment);
            tmp_xx(1:segLengths(i),i) = xx(n,segment,p)-(sum(xx(n,segment,p))/segLengths(i));
            tmp_yy(1:segLengths(i),i) = yy(n,segment,p)-(sum(yy(n,segment,p))/segLengths(i));
            
            
        end
        
        P_env_xx(1:Nsegments(n),n,p) = sum(tmp_xx.*tmp_xx,1)./segLengths ./ DC_power_x; % computing the envelope power
        P_env_yy(1:Nsegments(n),n,p) = sum(tmp_yy.*tmp_yy,1)./segLengths ./ DC_power_y;
        
        if sum(sum(isnan(P_env_xx(:,n,p))))
            P_env_xx(isnan(P_env_xx(:,n,p)),n,p) = 0;
        end
        
        if sum(sum(isnan(P_env_yy(:,n,p))))
            P_env_yy(isnan(P_env_yy(:,n,p)),n,p) = 0;
        end
        
        P_env_yy(:,n,p) = min(P_env_xx(:,n,p),P_env_yy(:,n,p));    %     The envelope power of the noise is the minimum of Penv of the mixture
        %     or the noise.
        
        xx_idx_nonZero   =  P_env_xx(:,n,p)~=0;
        yy_idx_nonZero   =  P_env_yy(:,n,p)~=0;
        threshold = 0.001;          % The envelope power cannot go below 0.001 (-30 dB) reflecting
        % our minimum threshold of sensitivity to modulation detection
        
        P_env_yy(yy_idx_nonZero,n,p) = max(  P_env_yy(yy_idx_nonZero,n,p),threshold);
        P_env_xx(xx_idx_nonZero,n,p)= max(P_env_xx(xx_idx_nonZero,n,p),threshold);
        
        SNRenvs_tmp = (P_env_xx(xx_idx_nonZero,n,p)-P_env_yy(yy_idx_nonZero,n,p)) ./P_env_yy(yy_idx_nonZero,n,p); % calculation of SNRenv
        
        SNRenvs_tmp = max(0.001,SNRenvs_tmp); % Truncated at -30 dB for numerical reasons.
        
        SNRenv_n_p(n,p) = mean(SNRenvs_tmp);%sqrt(sum(SNRenvs{q}.^2))/sum(SNRenvs{q});%
        
    end
    
    
end

% ----------------- Integrating the SNRenv across audio and modulation bands---------------------------------------------------

modFiltersMatrix = [[1:5 0 0 0 0]; [1:5 0 0 0 0]; [1:5 0 0 0 0]; [1:6 0 0 0]; [1:6 0 0 0]; [1:6 0 0 0];...
    [1:7 0 0] ; [1:7 0 0]; [1:7 0 0]; [1:8 0 ]; [1:8 0 ]; [1:8 0 ]; 1:9; 1:9; 1:9; 1:9;...
    1:9; 1:9; 1:9; 1:9; 1:9; 1:9;]';

SNRenv_n_p(modFiltersMatrix(:,bands) == 0) = 0;   %Only modulation filters with center frequency below
% 1/4 of the centerfrequency of a given audio
% channel is used. (Verhey, Dau, and Kollmeier, 1999)
SNRenv_p = sqrt(sum(SNRenv_n_p.^2,1));   %   Combine across modulation filters:  %SNRenv(p) eq. (4)

SNRenv = (sqrt(sum(SNRenv_p.^2)));%         Combine across audio filters: eq. (5)
output.SNRenv = SNRenv;

if nargin < 4
elseif nargin < 5
    P_correct = IdealObserver_v1(SNRenv,IO_param);
    output.P_correct = P_correct;
end
% ---------------------------------------------------------------------------------------------

end


function y = rms(x)
L = length(x);
y=norm(x)/sqrt(L);
end


function rms_out = thirdOctRMSAnalysis(x,fs,midfreq)

if nargin<3
    midfreq=[63 80 100 125 160 200 250 315 400 500 630 800 1000 1250 1600 2000 2500 3150 4000 5000 6300 8000 ];
end

N = length(x);
X = (fft(x));
X_mag  = abs(X) ;
X_power = X_mag.^2/N ;% power spectrum.
X_power_pos = X_power(1:fix(N/2)+1) ;
X_power_pos(2:end) = X_power_pos(2:end).* (2)  ; %take positive frequencies only and mulitply by two-squared to get the same total energy(used since the integration is only performed for positive freqiencies)

freq= linspace(0,fs/2,length(X_power_pos));

%resolution of data
resol=freq(2)-freq(1);

crossfreq(1)=midfreq(1)/(2^(1/6));
crossfreq(2:length(midfreq)+1)=midfreq*(2^(1/6));

%cross-over indicies
y=crossfreq/resol;

%rounding up
crosselem=round(y);
for n=1:length(y)
    if crosselem(n)<y(n)
        crosselem(n)=crosselem(n)+1;
    end
end

nn=1;
rms_out(1:length(midfreq)) = 0;
while crossfreq(nn+1)<=freq(end)% for nn =1:length(crossfreq)-1
    rms_out(nn) = sqrt(sum(X_power_pos(crosselem(nn):crosselem(nn+1)-1))/N);
    
    nn=nn+1;
    if 1+nn > length(crossfreq)
        break
    end
end

end


function x_filt = modFbank_v3(Env,fs,cf_mod)
%
% This function is an implementation of a modulation filterbank similar to the EPSM-filterbank
% as presented by Ewert & Dau 2000. This implementation consists of a lowpass
% filter with a cutoff at 1 Hz, in parallel with 8 bandpass filters with
% octave spacing. the Center-frequencies of the bandpass filters are lower
% than the original from Ewert & Dau (2000).
%
% Inputs:
%   Env:  The envelope to be filtered
%   fs: sampling frequency of the envelope
%   cf_mod:  centerfrequencies of the modulation filters
%
% Outputs:
%   x_filt:  Temporal outputs for each of the modulation filters
%
%
% Created by Søren Jørgensen jan 2010
% last update 07 mar 2014
% Copyright Søren Jørgensen

if nargin<3
    %band center frequencies
    cf_mod=[1 2 4 8 16 32 64 128 256];
end

if size(Env,1) > 1
    Env = Env';
end

if mod(length( Env),2) == 0
    %number is even
    Env =  Env(1:end-1);
else
    %number is odd
end

Q = 1;
N = length(Env);
X = fft(Env);
N_pos_specs = fix(N/2)+1;

pos_freqs= linspace(0,fs/2,N_pos_specs);
freqs = [pos_freqs -1*fliplr(pos_freqs(2:end))];

% Initialize transfer function
TFs = zeros(length(cf_mod),length(freqs));

% Calculating frequency-domain transferfunction for each center frequency:
for k = 2:length(cf_mod)
    TFs(k,1:end) = 1./(1+ (1j*Q*(freqs(1:end)./cf_mod(k) - cf_mod(k)./freqs(1:end)))); % p287 Hambley.
end

fcut = 1;% cutoff frequency of lowpassfilter:
n = 3;% order:
% Lowpass filter squared transfer function:
Wcf(1,:) =  1./(1+((2*pi*freqs/(2*pi*fcut)).^(2*n))); % third order butterworth filter TF from: http://en.wikipedia.org/wiki/Butterworth_filter

TFs(1,:) = sqrt(Wcf(1,:));

X = repmat(X,length(cf_mod),1);
X_filt = X.*TFs;
x_filt = real(ifft(X_filt,N,2));


end


function Pcorrect  = IdealObserver_v1(SNRenv_lin,parameters)
%%
% IdealObserver: Converts the overall SNRenv to percent correct.
%
% Usage: [Pcorrect SNRenv ] = IdealObserver(SNRenv_lin,parameters)
%
% SNRenv_lin :  vector with the SNRenv values (not in dB) for each input SNR
% Parameters :  vector with the parameters for the ideal Observer formatted as [k q m sigma_s]
%
% Søren Jørgensen august 2010
% last update 10-June 2013
% Copyright Søren Jørgensen
%%

if nargin < 2
    error('You have to specify the k,q,m,sigma_s parameters for the IdealObserver')
end
k = parameters(1);
q = parameters(2);
m = parameters(3);
sigma_s = parameters(4);


% ---------- Converting from SNRenv to d_prime  --------------
d_prime = k*(SNRenv_lin).^q;

%----------- Converting from d_prime to Percent correct, Green and Birdsall (1964)----------
Un = 1*norminv(1-(1/m));
mn = Un + (.577 /Un);% F^(-1)[1/n] Basically gives the value that would be drawn from a normal destribution with probability p = 1/n.
sig_n=  1.28255/Un;
Pcorrect = normcdf(d_prime,mn,sqrt(sigma_s.^2+sig_n.^2))*100;


% Green, D. M. and Birdsall, T. G. (1964). "The effect of vocabulary size",
% In Signal Detection and Recognition by Human Observers,
% edited by John A. Swets (John Wiley & Sons, New York)
end

