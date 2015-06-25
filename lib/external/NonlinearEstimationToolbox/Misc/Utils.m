
classdef Utils
    % This class provides various utility functions.
    %
    % Utils Methods:
    %   getMeanAndCov             - Compute sample mean and sample covariance.
    %   getMeanCovAndCrossCov     - Compute sample mean, covariance, and cross-covariance.
    %   kalmanUpdate              - Perform a Kalman update.
    %   blockDiag                 - Create a block diagonal matrix using the same matrix
    %                               mutiple times on the diagonal.
    %   baseBlockDiag             - Create a block diagonal matrix using a matrix multiple
    %                               times on the diagonal and add another matrix of the same
    %                               size to all matrix blocks.
    %   drawGaussianRndSamples    - Draw (multi-dimensional) random samples of a Gaussian
    %                               distribution with the specified mean and covariance.
    %   resampling                - Perform a simple resampling.
    %   systematicResampling      - Perform a systematic resampling.
    %   rndOrthogonalMatrix       - Creates a random orthogonal matrix of the specified dimension.
    %   getStateSamples           - Get a set of samples approximating a Gaussian distributed system state.
    %   getStateNoiseSamples      - Get a set of samples approximating a jointly Gaussian distributed system state and (system/measurement) noise.
    %   diffQuotientState         - Compute the state difference quotient of a function at 
    %                               the given nominal state.
    %   diffQuotientStateAndNoise - Compute the state and noise difference quotient of a 
    %                               function at the given nominal state and nominal noise.
    
    % >> This class is part of the Nonlinear Estimation Toolbox
    %
    %    For more information, see https://bitbucket.org/NonlinearEstimation/toolbox
    %
    %    Copyright (C) 2015  Jannik Steinbring <jannik.steinbring@kit.edu>
    %
    %                        Institute for Anthropomatics and Robotics
    %                        Chair for Intelligent Sensor-Actuator-Systems (ISAS)
    %                        Karlsruhe Institute of Technology (KIT), Germany
    %
    %                        http://isas.uka.de
    %
    %    This program is free software: you can redistribute it and/or modify
    %    it under the terms of the GNU General Public License as published by
    %    the Free Software Foundation, either version 3 of the License, or
    %    (at your option) any later version.
    %
    %    This program is distributed in the hope that it will be useful,
    %    but WITHOUT ANY WARRANTY; without even the implied warranty of
    %    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    %    GNU General Public License for more details.
    %
    %    You should have received a copy of the GNU General Public License
    %    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
    methods (Static)
        function [mean, cov] = getMeanAndCov(samples, weights)
            % Compute sample mean and sample covariance.
            %
            % Parameters:
            %   >> samples (Matrix)
            %      Column-wise arranged samples.
            %
            %   >> weights (Row vector)
            %      Column-wise arranged corresponding sample weights.
            %      If weights is an empty matrix, all samples are assumed
            %      to be equally weighted.
            %      Default: Empty matrix.
            %
            % Returns:
            %   << mean (Column vector)
            %      The sample mean.
            %
            %   << cov (Positive definite matrix)
            %      The sample covariance matrix.
            
            if nargin < 2
                numSamples = size(samples, 2);
                
                % Compute mean
                mean = sum(samples, 2) / numSamples;
                
                % Compute covariance
                if nargout > 1
                    diffSamples = bsxfun(@minus, samples, mean);
                    
                    cov = (diffSamples * diffSamples') / numSamples;
                end
            else
                % Compute mean
                mean = samples * weights';
                
                % Compute covariance
                if nargout > 1
                    diffSamples = bsxfun(@minus, samples, mean);
                    
                    weightedDiffSamples = bsxfun(@times, diffSamples, weights);
                    
                    cov = diffSamples * weightedDiffSamples';
                end
            end
        end
        
        function [measMean, measCov, ...
                  stateMeasCrossCov] = getMeanCovAndCrossCov(stateMean, stateSamples, ...
                                                             measSamples, weights)
            % Compute sample mean, covariance, and cross-covariance.
            %
            % Parameters:
            %   >> stateMean (Column vector)
            %      State mean.
            %
            %   >> stateSamples (Matrix)
            %      Column-wise arranged state samples.
            %
            %   >> measSamples (Matrix)
            %      Column-wise arranged measurement samples.
            %
            %   >> weights (Row vector)
            %      Column-wise arranged corresponding sample weights.
            %      If weights is an empty matrix, all samples are assumed
            %      to be equally weighted.
            %      Default: Empty matrix.
            %
            % Returns:
            %   << measMean (Column vector)
            %      The sample measurement mean.
            %
            %   << measCov (Positive definite matrix)
            %      The sample measurement covariance matrix.
            %
            %   << stateMeasCrossCov (Matrix)
            %      The sample state measurement cross-covariance matrix.
            
            if nargin < 4
                numSamples = size(stateSamples, 2);
                
                % Compute measurement mean
                measMean = sum(measSamples, 2) / numSamples;
                
                % Compute measurement covariance
                diffMeasSamples = bsxfun(@minus, measSamples, measMean);
                
                measCov = (diffMeasSamples * diffMeasSamples') / numSamples;
                
                % Compute state measurement cross-covariance
                diffStateSamples = bsxfun(@minus, stateSamples, stateMean);
                
                stateMeasCrossCov = (diffStateSamples * diffMeasSamples') / numSamples;
            else
                % Compute measurement mean
                measMean = measSamples * weights';
                
                % Compute measurement covariance
                diffMeasSamples = bsxfun(@minus, measSamples, measMean);
                
                weightedDiffMeasSamples = bsxfun(@times, diffMeasSamples, weights);
                
                measCov = diffMeasSamples * weightedDiffMeasSamples';
                
                % Compute state measurement cross-covariance
                diffStateSamples = bsxfun(@minus, stateSamples, stateMean);
                
                stateMeasCrossCov = diffStateSamples * weightedDiffMeasSamples';
            end
        end
        
        function [updatedStateMean, ...
                  updatedStateCov] = kalmanUpdate(stateMean, stateCov, measurement, ...
                                                  measMean, measCov, stateMeasCrossCov)
          	% Perform a Kalman update.
            
            [sqrtMeasCov, isNonPos] = chol(measCov);
            
            if isNonPos
                error('Utils:InvalidMeasurementCovariance', ...
                      'Measurement covariance matrix is not positive definite.');
            end
            
            % Compute Kalman gain
            A = stateMeasCrossCov / sqrtMeasCov;
            
            kalmanGain = A / sqrtMeasCov';
            
            % Compute updated state mean
            updatedStateMean = stateMean + kalmanGain * (measurement - measMean);
            
            % Compute updated state covariance
            updatedStateCov = stateCov - A * A';
        end
        
        function blockMat = blockDiag(matrix, numRepetitions)
            % Create a block diagonal matrix using the same matrix mutiple times on the diagonal.
            
            blockMat = kron(speye(numRepetitions), matrix);
        end
        
        function blockMat = baseBlockDiag(matrixBase, matrixDiag, numRepetitions)
            % Create a block diagonal matrix using a matrix multiple times on the diagonal and add another matrix of the same size to all matrix blocks.
            
            blockMat = repmat(matrixBase, numRepetitions, numRepetitions) + ...
                       Utils.blockDiag(matrixDiag, numRepetitions);
        end
        
        function rndSamples = drawGaussianRndSamples(mean, covSqrt, numSamples)
            % Draw (multi-dimensional) random samples of a Gaussian distribution with the specified mean and covariance.
            
            dim = size(mean, 1);
            
            rndSamples = covSqrt * randn(dim, numSamples);
            
            rndSamples = bsxfun(@plus, rndSamples, mean);
        end
        
        function rndSamples = resampling(samples, cumWeights, numSamples)
            % Perform a simple resampling.
            %
            % Parameters:
            %   >> samples (Matrix)
            %      Set of column-wise arranged sample positions to resample from.
            %
            %   >> cumWeights (Vector)
            %      Vector containing the cumulative sample weights.
            %
            %   >> numSamples (Positive scalar)
            %      Number of samples to draw from the given sample distribution.
            %
            % Returns:
            %   << rndSamples (Matrix)
            %      Column-wise arranged samples drawn from the given sample distribution.
            
            u = rand(1, numSamples);
            
            u = sort(u);
            
            idx = zeros(1, numSamples);
            
            i = 1;
            
            for j = 1:numSamples
                while u(j) > cumWeights(i)
                    i = i + 1;
                end
                
                idx(j) = i;
            end
            
            rndSamples = samples(:, idx);
        end
        
        function rndSamples = systematicResampling(samples, cumWeights, numSamples)
            % Perform a systematic resampling.
            %
            % Implements the systematic resampling algorithm from:
            %
            %   Branko Ristic, Sanjeev Arulampalam, and Neil Gordon,
            %   Beyond the Kalman Filter: Particle filters for Tracking Applications,
            %   Artech House Publishers, 2004,
            %   Section 3.3
            %
            % Parameters:
            %   >> samples (Matrix)
            %      Set of column-wise arranged sample positions to resample from.
            %
            %   >> cumWeights (Vector)
            %      Vector containing the cumulative sample weights.
            %
            %   >> numSamples (Positive scalar)
            %      Number of samples to draw from the given sample distribution.
            %
            % Returns:
            %   << rndSamples (Matrix)
            %      Column-wise arranged samples drawn from the given sample distribution.
            
            csw = cumWeights * numSamples;
            
            idx = zeros(1, numSamples);
            
        	u1 = rand(1);
            
            i = 1;
            
            for j = 1:numSamples
                uj = u1 + (j - 1);
                
                while uj > csw(i)
                    i = i + 1;
                end
                
                idx(j) = i;
            end
            
            rndSamples = samples(:, idx);
        end
        
        function rndMat = rndOrthogonalMatrix(dim)
            % Creates a random orthogonal matrix of the specified dimension.
            %
            % Parameters:
            %   >> dim (Positive scalar)
            %      Dimension of the desired random orthogonal matrix.
            %
            % Returns:
            %   << rndMat (Square matrix)
            %      A random orthogonal matrix of the specified dimension.
            
            mat = randn(dim, dim);
            
            [Q, R] = qr(mat);
            
            D = diag(sign(diag(R)));
            
            rndMat = Q * D;
        end
        
        function [stateSamples, ...
                  weights, ...
                  numSamples] = getStateSamples(sampling, stateMean, stateCovSqrt)
            % Get a set of samples approximating a Gaussian distributed system state.
            %
            % The number of samples, their positions, and their weights are determined (and
            % controlled) by the respective Gaussian sampling technique.
            %
            % Parameters:
            %   >> sampling (Subclass of GaussianSampling)
            %      Gaussian sampling technique that controls the sample generation.
            %
            %   >> stateMean (Column vector)
            %      State mean.
            %
            %   >> stateCovSqrt (Square matrix)
            %      Square root of the state covariance.
            %
            % Returns:
            %   << stateSamples (Matrix)
            %      Column-wise arranged sample positions approximating the Gaussian system state.
            %
            %   << weights (Row vector)
            %      Column-wise arranged corresponding sample weights.
            %
            %   << numSamples (Positive scalar)
            %      Number of samples approximating the Gaussian system state.
            
            dimState = size(stateMean, 1);
            
            % Get standard normal approximation
            [stdNormalSamples, weights, numSamples] = sampling.getStdNormalSamples(dimState);
            
            % Generate state samples
            stateSamples = stateCovSqrt * stdNormalSamples;
            stateSamples = bsxfun(@plus, stateSamples, stateMean);
        end
        
        function [stateSamples, ...
                  noiseSamples, ...
                  weights, ...
                  numSamples] = getStateNoiseSamples(sampling, stateMean, stateCovSqrt, ...
                                                     noiseMean, noiseCovSqrt)
            % Get a set of samples approximating a jointly Gaussian distributed system state and (system/measurement) noise.
            %
            % It is assumed that state and noise are mutually independent.
            %
            % The number of samples, their positions, and their weights are determined (and
            % controlled) by the respective Gaussian sampling technique.
            %
            % Parameters:
            %   >> sampling (Subclass of GaussianSampling)
            %      Gaussian sampling technique that controls the sample generation.
            %
            %   >> stateMean (Column vector)
            %      State mean.
            %
            %   >> stateCovSqrt (Square matrix)
            %      Square root of the state covariance.
            %
            %   >> noiseMean (Column vector)
            %      Noise mean.
            %
            %   >> noiseCovSqrt (Square matrix)
            %      Square root of the noise covariance.
            %
            % Returns:
            %   << stateSamples (Matrix)
            %      Column-wise arranged sample positions approximating the system state.
            %
            %   << noiseSamples (Matrix)
            %      Column-wise arranged samples approximating the noise.
            %
            %   << weights (Row vector)
            %      Column-wise arranged corresponding sample weights.
            %
            %   << numSamples (Positive scalar)
            %      Number of samples approximating the Gaussian joint distribution.
            
            dimState    = size(stateMean, 1);
            dimNoise    = size(noiseMean, 1);
            dimAugState = dimState + dimNoise;
            
            % Get standard normal approximation
            [stdNormalSamples, weights, numSamples] = sampling.getStdNormalSamples(dimAugState);
            
            % Generate state samples
            stateSamples = stateCovSqrt * stdNormalSamples(1:dimState, :);
            stateSamples = bsxfun(@plus, stateSamples, stateMean);
            
            % Generate noise samples
            noiseSamples = noiseCovSqrt * stdNormalSamples(dimState+1:end, :);
            noiseSamples = bsxfun(@plus, noiseSamples, noiseMean);
        end
        
        function stateJacobian = diffQuotientState(func, nominalState, step)
            % Compute the state difference quotient of a function at the given nominal state.
            
            % Default value for step
            if nargin < 3
                step = sqrt(eps);
            end
            
            dimState = size(nominalState, 1);
            
            % State jacobian
            stateSamples = bsxfun(@plus, [zeros(dimState, 1) step * eye(dimState)], nominalState);
            
            values = func(stateSamples);
            
            deltaStates = bsxfun(@minus, values(:, 2:end), values(:, 1));
            
            stateJacobian = deltaStates / step;
        end
        
        function [stateJacobian, noiseJacobian] = diffQuotientStateAndNoise(func, nominalState, nominalNoise, step)
            % Compute the state and noise difference quotient of a function at the given nominal state and nominal noise.
            
            % Default value for step
            if nargin < 4
                step = sqrt(eps);
            end
            
            dimState = size(nominalState, 1);
            dimNoise = size(nominalNoise, 1);
            
            % State jacobian
            stateSamples = bsxfun(@plus, [zeros(dimState, 1) step * eye(dimState)], nominalState);
            noiseSamples = repmat(nominalNoise, 1, 1 + dimState);
            
            values = func(stateSamples, noiseSamples);
            
            deltaStates = bsxfun(@minus, values(:, 2:end), values(:, 1));
            
            stateJacobian = deltaStates / step;
            
            % Noise jacobian
            stateSamples = repmat(nominalState, 1, 1 + dimNoise);
            noiseSamples = bsxfun(@plus, [zeros(dimNoise, 1) step * eye(dimNoise)], nominalNoise);
            
            values = func(stateSamples, noiseSamples);
            
            deltaNoise = bsxfun(@minus, values(:, 2:end), values(:, 1));
            
            noiseJacobian = deltaNoise / step;
        end
    end
end
