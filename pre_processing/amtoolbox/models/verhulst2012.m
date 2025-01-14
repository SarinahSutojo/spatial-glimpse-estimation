function [V,Y,OAE,CF]=verhulst2012(sign,fs,fc,spl,varargin)
%VERHULST2012 Process a signal with the cochlear model by Verhulst et. al. 2012
%   Usage: output = verhulst2012(insig,fs,fc,varargin)
%
%   Input parameters:
%      sign             : the input signal to be processed [time channel]. 
%                         Each channel will be independently processed in parallel.
%      fs               : sampling rate (Hz)
%      fc               : list of frequencies specifying the probe positions on
%                         the basilar membrane, or 'all' to probe all 1000
%                         cochlear sections
%      spl              : array of SPLs that correspond to
%                         value 1 of the correspondent input channel
%      'normalizeRms',n : array to control the normalization of each
%                         channel. With value 1 normalize the energy of the signal, so the
%                         SPL corresponds to the RMS of the signal (default 0)
%      'subject',s      : the subject number controling the cochlear irregulatiries (default 1)
%      'irr',i          : array that enable (1) or disable (0)
%                         irregularities and nonlinearities for each simulation (default 1)                
%       
%   Output parameters:
%       V  : velocity of the basilar membrane sections V(time,section,channel) 
%       Y  : displacement of the basilar membrane sections Y(time,section,channel)
%       OAE : otto-acoustic emissions given by sound pressure at the middle ear
%       CF : center frequencies of the probed basiliar membrane sections
%
%   This function computes the basilar membrane displacement and the
%   velocity of the movement at different positions employing a faster
%   implementation of the nonlinear time-domain model of cochlea by
%   Verhulsts, Dau, Shera 2012, through the method described in Altoe et
%   al. 2014
%
%   The processing is implemented as follows:
%
%   1) the input signal is resampled to the 96 kHz sampling rate
%      employed in the cochlea model
%
%   2) the list of frequencies in fc are converted in to probe
%      positions in a manner that the frequencies are divided evenly into
%      low and high frequency categories. 
%
%   3) the signals are processed in parallel
%
%   4) the values obtained are resampled back to the original sampling
%      rate
%
%   Requirements and installation: 
%   ------------------------------
%
%   1) Python >2.6 is required with numpy and scipi packages. On Linux, use sudo apt-get install python-scipy python-numpy
% 
%   2) Compiled files with a C-compiler, e.g. gcc. In amtbase/src/verhulst start make (Linux) or make.bat (Windows)
%
%   3) On linux, when problems with GFORTRAN lib appear, try sudo ln -sf /usr/lib64/libgfortran.so.3.0.0 /mymatlabroot/sys/os/glnxa64/libgfortran.so.3 (mymatlabroot is usually /usr/local/MATLAB/version
%               
%   See also: verhulst2015 verhulst2018 demo_verhulst2012
%             verhulst2018_ihctransduction verhulst2015_cn
%             verhulst2015_ic verhulst2018_auditorynerve exp_verhulst2012
%             verhulst2012 verhulst2015
%             verhulst2018 middleearfilter data_takanen2013 takanen2013_periphery
%             exp_osses2022 exp_takanen2013 takanen2013
%
%   References:
%     S. Verhulst, T. Dau, and C. A. Shera. Nonlinear time-domain cochlear
%     model for transient stimulation and human otoacoustic emission. J.
%     Acoust. Soc. Am., 132(6):3842 -- 3848, 2012.
%     
%     A. Altoè, S. Verhulst, and V. Pulkki. Transmission line cochlear
%     models: improved accuracy and efficiency. J. Acoust. Soc. Am.,
%     136:EL302--EL308, 2014.
%     
%
%   Url: http://amtoolbox.org/amt-1.1.0/doc/models/verhulst2012.php

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

%   #StatusDoc: Perfect
%   #StatusCode: Perfect
%   #Verification: Verified
%   #Requirements: MATLAB M-Signal PYTHON3 C
%   #Author: Alessandro Altoe' 

definput.import={'verhulst2012'};  % load defaults from arg_verhulst2012

[flags,keyvals]  = ltfatarghelper([],definput,varargin);


if isempty(keyvals.normalize),
    [channels,idx]=min(size(sign));
    normalizeRMS=zeros(channels,1);
else
  normalizeRMS=keyvals.normalize; 
end

if isempty(keyvals.irr)
    [channels,idx]=min(size(sign));
    irregularities=ones(1,channels);
else
  irregularities = keyvals.irr;
end

subject=keyvals.subject;
modfs=96000;
sectionsNo=1000;
[channels,idx]=min(size(sign));
if(idx==2) %transpose it (python C-style row major order)
    sign=sign';
end
stim=zeros(channels,length(resample(sign(1,:),modfs,fs)));
for i=1:channels
    stim(i,:)=resample(sign(i,:),modfs,fs);
    if normalizeRMS(i)
        s_rms=rms(stim(i,:));
        stim(i,:)=stim(i,:)./s_rms;
    end
end
% sheraPo=0.061;
if(isstr(fc) && strcmp(fc,'all')) %if probing all sections 1001 output (1000 sections plus the middle ear)
    p=sectionsNo;
else %else pass it as a column vector
    [p,idx]=max(size(fc));
    if(idx==2)
        fc=fc'; 
    end
    fc=round(fc);
end
len=length(stim(1,:));

% probes=fc; Fs=modfs; sheraPo=0.061;
% path=fileparts(which('verhulst2012'));
% path=fileparts(path);
% act_path=pwd;
% cd(strcat(path,'/environments/verhulst2012/')); 
% save('input.mat','stim','Fs','channels','spl','subject','sheraPo','irregularities','probes','-v7');
% system('python run_cochlear_model.py');

in.stim=stim; in.Fs=modfs; in.channels=channels; in.spl=spl; 
in.subject=subject; in.sheraPo=0.061; in.irregularities=irregularities;
in.probes=fc;
out.v=[p len channels];
out.y=[p len channels];
out.E=[len 1 channels];
out.F=[p 1];
output=amt_extern('Python','verhulst2012','run_cochlear_model.py',in,out); 
Vs=output.v;
Ys=output.y;
OAEs=squeeze(output.E);
CF=output.F;

% Vs=zeros(p,len,channels);
% Ys=zeros(p,len,channels);
% OAEs=zeros(len,channels);
% for i=1:channels
%     fname=strcat('out/v',int2str(i),'.np');
%     f=fopen(fname,'r');
%     Vs(:,:,i)=fread(f,[p,len],'double','n');
%     fclose(f);
%     fname=strcat('out/y',int2str(i),'.np');
%     f=fopen(fname,'r');
%     Ys(:,:,i)=fread(f,[p,len],'double','n');
%     fclose(f);
%     fname=strcat('out/E',int2str(i),'.np');
%     f=fopen(fname,'r');
%     OAEs(:,i)=fread(f,[len,1],'double','n');
%     fclose(f);
%     if(i==1)
%       fname=strcat('out/F',int2str(i),'.np');
%       f=fopen(fname,'r');
%       CF=fread(f,[p,1],'double','n');
%       fclose(f);
%     end
% end

rl=length(resample(stim(1,:),fs,modfs));
V=zeros(rl,p,channels);
Y=zeros(rl,p,channels);
OAE=zeros(rl,channels);

for i=1:channels
    V(:,:,i)=resample(squeeze(Vs(:,:,i))',fs,modfs);
    Y(:,:,i)=resample(squeeze(Ys(:,:,i))',fs,modfs);
    OAE(:,i)=resample(squeeze(OAEs(:,i)),fs,modfs);
end
% cd(act_path);

