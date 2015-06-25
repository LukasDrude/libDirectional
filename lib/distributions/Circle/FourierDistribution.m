classdef FourierDistribution < AbstractCircularDistribution
    % Used to represent circular densities with Fourier
    % series
    %#ok<*PROP>
    %
    % Florian Pfaff, Gerhard Kurz, Uwe D. Hanebeck,
    % Multimodal Circular Filtering Using Fourier Series
    % Proceedings of the 18th International Conference on Information Fusion (Fusion 2015), Washington D. C., USA, July 2015.
    
    properties
        a
        b
        transformation
    end
    
    methods
        function this = FourierDistribution(a,b,transformation)
            if isa(a,'AbstractCircularDistribution')
                error('You gave a distribution as the first argument. To convert distributions to a distribution in Fourier representation, use .fromDistribution');
            end
            assert(length(b)==(length(a)-1),'Coefficients have incompatible lengths');
            if nargin==2 % Square root of density is standard case
                this.transformation='sqrt';
            else
                this.transformation=transformation;
            end
            this.a=a;
            this.b=b;
            % Check if normalized. If not: Normalize!
            this=this.normalize;
        end
        
        function p = pdf(this, xa)
            % Evaluate pdf at each column of xa
            %
            % Parameters:
            %   xa (1 x n)
            %       n locations where to evaluate the pdf
            % Returns:
            %   p (1 x n)
            %       value of the pdf at each location
            assert(size(xa,1)==1);
            % Evaluate actual pdf at xa (transformations need to be performed)
            val=value(this,xa);
            switch this.transformation
                case 'sqrt'
                    p=val.^2;
                case 'identity'
                    p=val;
                case 'log'
                    warning('Density may not be normalized');
                    p=exp(val);
                otherwise
                    error('Transformation not recognized or unsupported');
            end
        end
        
        function result = integral(this, l, r)
            % Calculates the integral of the pdf from l to r analytically
            % if possible, fall back to numerical calculation by default
            %
            % Parameters:
            %   l (scalar)
            %       left bound of integral, default 0
            %   r (scalar)
            %       right bound of integral, default 2*pi
            % Returns:
            %   result (scalar)
            %       value of the integral
            if strcmp(this.transformation,'sqrt') %transform to identity
                fd=this.transformViaCoefficients('square',2*length(this.a)+1);
            elseif ~strcmp(this.transformation,'identity') %if not possible to transform to identity, give up
                error('Cdf not supported for this transformation')
            else
                fd=this;
            end
            c=fd.c;
            c0=c((length(c)+1)/2);
            cnew=fd.c./(1i*(-length(fd.b):length(fd.b))); %Calculate coefficients != 0 for antiderivative
            % To avoid unwanted normalization by the constructor, we set
            % c0=1/(2*pi). We do not have to address this further as +c to the
            % indefinite integral does not change the value of the definite integral.
            cnew((length(cnew)+1)/2)=1/(2*pi); 
            fdInt=FourierDistribution.fromComplex(cnew,'identity'); 
            result=fdInt.value(r)-fdInt.value(l)+c0*(r-l);
        end
       
        function p = value(this,xa)
            % Evalute current Fourier series without undoing transformations
            xa=reshape(xa,[],1);
            p=this.a(1)/2+sum(repmat(this.a(2:end),[length(xa),1]).*cos(xa*(1:length(this.a)-1))+repmat(this.b,[length(xa),1]).*sin(xa*(1:length(this.b))),2)';
        end
        
        function m = trigonometricMoment(this, n)
            % Calculate n-th trigonometric moment analytically
            %
            % Parameters:
            %   n (scalar)
            %       number of moment
            % Returns:
            %   m (scalar)
            %       n-th trigonometric moment (complex number)
            if n==0
                m=1;
            elseif n<0
                m=conj(trigonometricMoment(this,-n));
            else
                switch this.transformation
                    case 'sqrt'
                        fdtmp=this.transformViaCoefficients('square',4*length(this.b)+1);
                        atmp=fdtmp.a;
                        btmp=fdtmp.b;
                    case 'identity'
                        atmp=this.a;
                        btmp=this.b;
                    otherwise
                        error('Transformation not recognized or unsupported');
                end
                if n>length(btmp)
                    m=0;
                else
                    m=pi*conj(atmp(n+1)-1i*btmp(n));
                end
            end
        end
        
        function complexCoeffs = c(this)
            % Get complex coefficients
            complexCoeffs=NaN(1,length(this.a)+length(this.b));
            complexCoeffs((length(complexCoeffs)+1)/2)=this.a(1)/2;
            complexCoeffs((length(complexCoeffs)+3)/2:end)=(this.a(2:end)-1i*this.b)/2;
            % We know pdf is real, so we can use complex conjugation
            complexCoeffs(1:(length(complexCoeffs)-1)/2)=conj(fliplr(complexCoeffs((length(complexCoeffs)+3)/2:end)));
        end
        
        function f = multiply(this, f2)
            assert(isa (f2, 'FourierDistribution'));
            % Multiplies two transformed fourier pdfs (returns transformed result)
            if ~strcmp(this.transformation,f2.transformation);
                error('Multiply:differentTransformations','Transformations do not match, transform before using multiply');
            end
            if strcmp(this.transformation,'log')
                warning('Not performing normalization when using log transformation');
                f=FourierDistribution(this.a+f2.a,this.b+f2.b,'log');
            elseif strcmp(this.transformation,'identity')||strcmp(this.transformation,'sqrt')
                % Calculate unnormalized result
                c=conv(this.c,f2.c);
                % Normalization is performed in constructor. Temporarily
                % disabling warning.
                warnStruct=warning('off','Normalization:notNormalized');
                f=FourierDistribution.fromComplex(c,this.transformation); 
                warning(warnStruct);
            else
                error('Multiply:unsupportedTransformation','Transformation not recognized or unsupported');
            end
            
        end
        
        function f = normalize(this)
            % Normalize Fourier density while taking its type into account
            switch this.transformation
                case 'sqrt'
                    % Calculate normalization factor and return normalized
                    % result
                    cSquare=conv(this.c,this.c);
                    a0=real(cSquare((length(cSquare)+1)/2))*2;
                    if(abs(a0-1/pi)<1e-4)
                        f=this;
                    elseif (a0<1e-6)
                        error('a0 is too close to zero, this usually points to a user error');
                    else
                        warning('Normalization:notNormalized','Coefficients apparently do not belong to normalized density. Normalizing...');
                        f=FourierDistribution(this.a/sqrt(a0*pi),this.b/sqrt(a0*pi),this.transformation);
                    end
                case 'identity'
                    % Calculate normalization factor and return normalized
                    % result
                    a0=this.a(1);
                    if (abs(a0-1/pi)<1e-6)
                        f=this;
                    elseif (a0<1e-6)
                        error('a0 is too close to zero, this usually points to a user error');
                    else
                        warning('Normalization:notNormalized','Coefficients apparently do not belong to normalized density. Normalizing...');
                        f=FourierDistribution(this.a/(a0*pi),this.b/(a0*pi),this.transformation);
                    end
                otherwise
                    warning('Normalization:cannotTest','Unable to test if normalized');
                    f=this;
            end
        end
        
        function f = convolve(this, f2, noOfCoefficients)
            % Calculates convolution of two Fourier series
            % Expects number of complex coefficients (or sum of number of real
            % coefficients) to know how many points to sample for FFT
            if ~strcmp(this.transformation,f2.transformation);
                error('Convolve:differentTransformations','Transformations do not match, transform before using convolve');
            end
            if nargin==2,noOfCoefficients=length(this.a)+length(this.b);end
            c1=this.c;
            c2=f2.c;
            switch this.transformation
                case 'sqrt'
                    % Calculate convolution in an exact fashion by first 
                    % obtaining coefficients for the identity and then using
                    % the Hadamard product
                    cConv=2*pi*conv(c1,c1).*conv(c2,c2);
                    ftmp=FourierDistribution.fromComplex(cConv,'identity');
                    % Calculate coefficients for sqrt
                    f=ftmp.transformViaFFT('sqrt',noOfCoefficients);
                case 'log'
                    % Calculate function values and then calculate cyclic
                    % convolution via fft, this is already an approximation
                    fvals1=exp(ifft(ifftshift(c1))*length(c1));
                    fvals2=exp(ifft(ifftshift(c2))*length(c2));
                    ctmp=fftshift(fft(fvals1).*fft(fvals2));
                    ctmp=ctmp/length(ctmp);
                    ftmp=FourierDistribution.fromComplex(ctmp,'identity');
                    % Calculate coefficients for log
                    f=ftmp.transformViaFFT('log',noOfCoefficients);
                case 'identity'
                    % This can be done in an exact fashion
                    cConv=2*pi*c1.*c2;
                    ftmp=FourierDistribution.fromComplex(cConv,'identity');
                    f=ftmp.truncate(noOfCoefficients);
                otherwise
                    error('Convolve:unsupportedTransformation','Transformation not recognized or unsupported');
            end
        end
        
        function f = truncate(this,noOfCoefficients)
            % Truncates Fourier series. Fills up if there are less coefficients
            % Expects number of complex coefficients (or sum of number of real
            % coefficients)
        
            assert((noOfCoefficients-1>0) && (mod(noOfCoefficients-1,2)==0),'Invalid number of coefficients, number has to be odd');
            if ((noOfCoefficients+1)/2)<=length(this.a)
                f=FourierDistribution(this.a(1:((noOfCoefficients+1)/2)),...
                this.b(1:((noOfCoefficients-1)/2)),this.transformation);
            else 
                warning('Truncate:TooFewCoefficients','Less coefficients than desired, filling up with zeros')
                diff=(noOfCoefficients+1)/2-length(this.a);
                f=FourierDistribution([this.a,zeros(1,diff)],[this.b,zeros(1,diff)],this.transformation);
            end
        end
        
        function f = transformViaCoefficients(this,desiredTransformation,noOfCoefficients)
            % Calculates transformations using Fourier coefficients
            if nargin==2,noOfCoefficients=length(this.a)+length(this.b);end
            switch desiredTransformation
                case 'identity'
                    f=this;
                case 'square'
                    switch this.transformation
                        case 'sqrt'
                            transformation='identity';
                        case 'identity'
                            transformation='square';
                        otherwise
                            transformation='multiple';
                    end
                    c=conv(this.c,this.c);
                    f=FourierDistribution.fromComplex(c,transformation);
                otherwise
                    error('Desired transformation not supported via coefficients');
            end
            f=f.truncate(noOfCoefficients); 
        end
        
        function f = transformViaFFT(this,desiredTransformation,noOfCoefficients)
            % Calculates transformation of Fourier series via FFT
            % Expects number of complex coefficients (or sum of number of real
            % coefficients)
            if ~strcmp(this.transformation,'identity')
                error('Transformation:alreadyTransformed','Cannot transform via FFT if already transformed')
            end
            if nargin==2,noOfCoefficients=length(this.a)+length(this.b);end
            fvals=ifft(ifftshift(this.c))*length(this.c); %Calculate function values via IFFT
            f=FourierDistribution.fromFunctionValues(fvals,noOfCoefficients,desiredTransformation);
        end
        
        function f = transformViaVM(this,desiredTransformation,noOfCoefficients)
            % Calculates transformation of Fourier series via approximation with a von Mises distribution
            % Expects number of complex coefficients (or sum of number of real
            % coefficients)
            if ~strcmp(this.transformation,'identity')
                error('Transformations of already transformed density via von Mises not supported');
            end
            if nargin==2,noOfCoefficients=length(this.a)+length(this.b);end
            assert((noOfCoefficients-1>0) && (mod(noOfCoefficients-1,2)==0),'Invalid number of coefficients, number has to be odd');
            vmEquivalent=VMDistribution.fromMoment(this.a(2)*pi+1i*this.b(1)*pi);
            switch desiredTransformation
                case 'sqrt'
                    f=FourierDistribution.fromDistribution(vmEquivalent,noOfCoefficients,'sqrt');
                case 'log'
                    f=FourierDistribution.fromDistribution(vmEquivalent,noOfCoefficients,'log');
                otherwise 
                    error('Transformation not recognized or unsupported');
            end
        end
        
        function f = shift(this, angle)
            % Returns Fourier Distribution which is shifted (towards positivity) by a given angle
            anew=[this.a(1),arrayfun(@(k)this.a(k+1)*cos(-k*angle)+this.b(k)*sin(-k*angle),1:length(this.b))];
            bnew=arrayfun(@(k)this.b(k)*cos(-k*angle)-this.a(k+1)*sin(-k*angle),1:length(this.b));
            f=FourierDistribution(anew,bnew,this.transformation);
        end
    end
    
    methods (Static)
        function f = fromComplex(c,transformation)
            % Create density from complex coefficients
            assert(abs(c((length(c)+1)/2))>0,'c0 is zero, cannot normalize to valid density.')
            % Using flipping to neither favor negative nor positive
            % indicies (although c_k=conj(c_-k) should hold)
            tmp=c+fliplr(c);
            % Ensure all coefficients to be real due to numerical imprecision
            a=real(tmp(((length(c)+1)/2):end)); %a_0..a_n
            tmp=c-fliplr(c);
            b=-imag(tmp(((length(c)+3)/2):end)); %b_1..b_n
            f=FourierDistribution(a,b,transformation);
        end
        
        function f = fromFunction(fun,noOfCoefficients,desiredTransformation)
            % Creates Fourier distribution from function
            % Function must be able to take vector arguments
            assert(isa(fun, 'function_handle'));
            if nargin==2,desiredTransformation='sqrt';end;
            N=2^ceil(log2(noOfCoefficients));
            xvals=linspace(0,2*pi,N+1);
            xvals=xvals(1:end-1);
            fvals=fun(xvals);
            f=FourierDistribution.fromFunctionValues(fvals,noOfCoefficients,desiredTransformation);
        end
        
        function f = fromFunctionValues(fvals,noOfCoefficients,desiredTransformation)
            % Creates Fourier distribution from function values
            % Assumes fvals are not yet transformed, use custom if they already
            % are transformed
            assert((noOfCoefficients-1>0) && (mod(noOfCoefficients-1,2)==0),'Invalid number of coefficients');
            
            switch desiredTransformation
                case 'sqrt'
                    fvals=sqrt(fvals);
                case 'log'
                    fvals=log(fvals);
                case 'identity' %keep them unchanged
                case 'custom' %already transformed
                otherwise
                    error('Transformation not recognized or unsupported by transformation via FFT');
            end
            transformed=fftshift(fft(fvals))/length(fvals);
            if mod(length(fvals),2)==0 % An additional a_k could be obtained but is discarded
                transformed(1)=[];
            end
            ftmp=FourierDistribution.fromComplex(transformed,desiredTransformation);
            f=ftmp.truncate(noOfCoefficients); 
        end
        
        function f=fromDistribution(distribution,noOfCoefficients,desiredTransformation)
            % Creates Fourier distribution from a different distribution
            assert(isa(distribution,'AbstractCircularDistribution'),'First argument has to be a circular distribution.');
            assert((noOfCoefficients-1>0) && (mod(noOfCoefficients-1,2)==0),'Invalid number of coefficients, number has to be odd');
            if nargin==2
                desiredTransformation='sqrt';
            end
            lastk=(noOfCoefficients-1)/2;
            switch class(distribution)
                case 'VMDistribution'
                    switch desiredTransformation
                        case 'sqrt'
                            a=2/sqrt(2*pi*besseli(0,distribution.kappa))*besseli(0:lastk,0.5*distribution.kappa);
                        case 'identity'
                            a=[1/pi,...
                                1/(pi*besseli(0,distribution.kappa))*besseli(1:lastk,distribution.kappa)];
                        case 'log'
                            a=[-2*log(2*pi*besseli(0,distribution.kappa)),distribution.kappa,zeros(1,lastk-1)];
                        otherwise 
                            error('Transformation not recognized or unsupported');
                    end
                    f=FourierDistribution(a,zeros(1,length(a)-1),desiredTransformation);
                    if ~(distribution.mu==0)
                        f=f.shift(distribution.mu);
                    end
                case 'WNDistribution'
                    switch desiredTransformation
                        case 'sqrt'
                            warning('Conversion:NoFormulaSqrt','No explicit formula available, using FFT to get sqrt');
                            f=FourierDistribution.fromFunction(@distribution.pdf,noOfCoefficients,desiredTransformation);
                        case 'identity'
                            a=[1/pi,...
                                arrayfun(@(k)exp(-distribution.sigma^2*k^2/2)/pi,1:lastk)];
                            f=FourierDistribution(a,zeros(1,length(a)-1),desiredTransformation);
                        case 'log'
                            % Using first 1000 components to approximate
                            % log of euler function/q-pochhammer
                            logeuler=sum(log(1-exp(-distribution.sigma^2*(1:1000))));
                            a0=2*(-log(2*pi)+logeuler);
                            a1end=arrayfun(@(k)2*(-1)^(k)/k*(exp(0.5*k*distribution.sigma^2)/(1-exp(k*distribution.sigma^2))),1:lastk);
                            a=[a0,a1end];
                            f=FourierDistribution(a,zeros(1,length(a)-1),desiredTransformation);
                        otherwise 
                            error('Transformation not recognized or unsupported');
                    end
                    if ~(distribution.mu==0)&&~strcmp(desiredTransformation,'sqrt')
                        f=f.shift(distribution.mu);
                    end
                case 'WCDistribution'
                    switch desiredTransformation
                        case 'sqrt'
                            warning('Conversion:ApproximationHypergeometric','The implementation of the regularized hypergeometric function may not be accurate numerically. This can lead to unnormalized densities');
                            noOfSummands=1000;
                            % Cannot use log of gamma (which would be
                            % better numerically) as MATLAB currently does
                            % not support negative values for gammaln
                            afun=@(n,k)gamma(n+1/2).^2.*sech(distribution.gamma/2).^(2.*n)./(gamma(1-k+n).*gamma(1+k+n));
                            a=NaN(1,lastk+1);
                            for k=0:lastk
                                vals=afun(0:noOfSummands,k);
                                a(k+1)=sum(vals(~isnan(vals)))*sqrt(2/(pi^3)*tanh(distribution.gamma/2));
                            end
                        case 'identity'
                            a=arrayfun(@(k)exp(-k*distribution.gamma)/pi,0:lastk);
                        case 'log'
                            a=[2*log((1-exp(-2*distribution.gamma))/(2*pi)),...
                                arrayfun(@(k)2*exp(-k*distribution.gamma)/k,1:lastk)];
                        otherwise 
                            error('Transformation not recognized or unsupported');
                    end
                    f=FourierDistribution(a,zeros(1,length(a)-1),desiredTransformation);
                    if ~(distribution.mu==0)
                        f=f.shift(distribution.mu);
                    end
                case 'WEDistribution'
                    switch desiredTransformation
                        case 'sqrt'
                            afun=@(k)2*distribution.lambda^(3/2)./(pi*sqrt(exp(2*pi*distribution.lambda)-1)*(4*k.^2+distribution.lambda^2))...
                                *(exp(pi*distribution.lambda)-1);
                            bfun=@(k)4*k*distribution.lambda^(1/2)./(pi*sqrt(exp(2*pi*distribution.lambda)-1)*(4*k.^2+distribution.lambda^2))...
                                *(exp(distribution.lambda*pi)-1);
                            a=afun(0:lastk);
                            b=bfun(1:lastk);
                        case 'identity'
                            a=[1/pi,...
                                arrayfun(@(k)1/pi*distribution.lambda^2/(distribution.lambda^2+k^2),1:lastk)];
                            b=arrayfun(@(k)1/pi*distribution.lambda*k/(distribution.lambda^2+k^2),1:lastk);
                        case 'log'
                            a=[-2*pi*distribution.lambda-2*log(1-exp(-2*pi*distribution.lambda))+2*log(distribution.lambda),...
                                zeros(1,lastk)];
                            b=arrayfun(@(k)2*distribution.lambda/k,1:lastk);
                        otherwise 
                            error('Transformation not recognized or unsupported');
                    end
                    f=FourierDistribution(a,b,desiredTransformation);
                case 'WLDistribution'
                    switch desiredTransformation
                        case 'sqrt'
                            warning('Conversion:NoFormulaSqrt','No explicit formula available, using FFT to get sqrt');
                            f=FourierDistribution.fromFunction(@distribution.pdf,noOfCoefficients,desiredTransformation);
                        case 'identity'
                            a0=1/pi;
                            a1end=arrayfun(...
                                @(k)1/pi*distribution.kappa^2*distribution.lambda^2*(k^2+distribution.lambda^2)/...
                                ((distribution.lambda^2*distribution.kappa^2+k^2)*(distribution.kappa^2*k^2+distribution.lambda^2)),...
                                1:lastk);
                            b=arrayfun(...
                                @(k)1/pi*distribution.kappa*distribution.lambda^3*k*(1-distribution.kappa^2)/...
                                ((distribution.lambda^2*distribution.kappa^2+k^2)*(distribution.kappa^2*k^2+distribution.lambda^2)),...
                                1:lastk);
                            f=FourierDistribution([a0,a1end],b,desiredTransformation);
                        case 'log'
                            warning('Conversion:NoFormulaLog','No explicit formula available, using FFT to get log');
                            f=FourierDistribution.fromFunction(@distribution.pdf,noOfCoefficients,desiredTransformation);
                        otherwise 
                            error('Transformation not recognized or unsupported');
                    end
                case 'CUDistribution'
                    switch desiredTransformation
                        case 'sqrt'
                            a=[sqrt(2/pi),zeros(1,lastk)];
                        case 'identity'
                            a=[1/pi,zeros(1,lastk)];
                        case 'log'
                            a=[-2*log(2*pi),zeros(1,lastk)];
                        otherwise 
                            error('Transformation not recognized or unsupported');
                    end
                    f=FourierDistribution(a,zeros(1,length(a)-1),desiredTransformation);
                case 'WDDistribution'
                    ctmp=arrayfun(@(i)distribution.trigonometricMoment(i),0:lastk);
                    c=[fliplr(conj(ctmp(2:end))),ctmp(1:end)];
                    ftmp=FourierDistribution.fromComplex(c,'identity');
                    switch desiredTransformation    
                        case 'identity' 
                            f=ftmp;
                        case 'sqrt'
                            warning('Conversion:NoFormulaSqrt','No explicit formula available, using FFT to get sqrt');
                            f=ftmp.transformViaFFT('sqrt',noOfCoefficients);
                        case 'log'
                            warning('Conversion:NoFormulaLog','No explicit formula available, using FFT to get log');
                            f=ftmp.transformViaFFT('log',noOfCoefficients);
                        otherwise 
                            error('Transformation not recognized or unsupported');
                    end
                case 'GeneralCircularMixture'
                    switch desiredTransformation
                        case 'sqrt'
                            warning('Conversion:NoFormulaSqrt','No explicit formula available, using FFT to get sqrt');
                            f=FourierDistribution.fromFunction(@distribution.pdf,noOfCoefficients,desiredTransformation);
                        case 'identity'
                            a=zeros(1,lastk+1);
                            b=zeros(1,lastk);
                            for i=1:length(distribution.cds)
                                fCurr=FourierDistribution.fromDistribution(distribution.cds(i),noOfCoefficients,desiredTransformation);
                                a=a+fCurr.a*distribution.w(i);
                                b=b+fCurr.b*distribution.w(i);
                                f=FourierDistribution(a,b,'identity');
                            end
                        case 'log'
                            warning('Conversion:NoFormulaLog','No explicit formula available, using FFT to get log');
                            f=FourierDistribution.fromFunction(@distribution.pdf,noOfCoefficients,desiredTransformation);
                        otherwise 
                            error('Transformation not recognized or unsupported');
                    end
                otherwise
                    warning('No explicit formula available, using FFT to get transformation');
                    f=FourierDistribution.fromFunction(@distribution.pdf,noOfCoefficients,desiredTransformation);
            end
        end
    
    end
end
