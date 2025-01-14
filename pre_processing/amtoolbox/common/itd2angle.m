function phi = itd2angle(itd,lookup)
% ITD2ANGLE converts the given ITD to an angle using a lookup table
%   Usage: phi = itd2angle(itd,lookup)
%
%   Input parameters:
%       itd     : ITDs to convert to angles
%       lookup  : a struct containing the polinomial fitting entries p,MU,S.
%                 This struct can be generated by ITD2ANGLE_lookuptable
%
%   Output parameters:
%       phi     : angles for the corresponding ITD values / deg
%
%   ITD2ANGLE(itd,lookup) converts the given ITD values to azimuth angles phi.
%   Therefore a lookup table containing the polynomial fitting parameters is
%   used. This lookup table is created from a set of HRTFs with known azimuth
%   angles and stores the corresponding ITD values. itd2angle works with
%   DIETZ2011 and LINDEMANN1986. Corresponding lookup tables can be created
%   by ITD2ANGLE_LOOKUPTABLE.
%
%   Url: http://amtoolbox.org/amt-1.1.0/doc/common/itd2angle.php

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

% AUTHOR: Mathias Dietz, Hagen Wierstorf (for AMT)


%% ===== Checking of input parameters ====================================
nargmin = 2;
nargmax = 2;
narginchk(nargmin,nargmax);


%% ===== Computation =====================================================
phi = zeros(size(itd));

for n = 1:size(itd,2)
    % by calling the output S and MU, phi is z-scored, thus improving the fitting
    phi(:,n)=polyval(lookup.p(:,n),itd(:,n),lookup.S{n},lookup.MU(:,n));
end
% neglect angles > 95°. Warning => maybe systematic underestimation for azi ~ 90°
phi(abs(phi)>95) = NaN;

