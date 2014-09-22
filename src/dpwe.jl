# PVOC Stretching
# algorithm ported directly from Dan Ellis:
#
# @misc{Ellis02-pvoc
#  author = {D. P. W. Ellis},
#  year = {2002},
#  title = {A Phase Vocoder in {M}atlab},
#  note = {Web resource},
#  url = {http://www.ee.columbia.edu/~dpwe/resources/matlab/pvoc/},
#}

function pvsample{T<:Complex}(b::Array{T}, t::AbstractArray, hop::Integer=(size(b, 1)-1))
    # Interpolate an STFT array according to the 'phase vocoder'.
    # b is an STFT array, of the form generated by 'stft'.
    # t is a vector of (real) time-samples, which specifies a path through 
    # the time-base defined by the columns of b.  For each value of t, the
    # spectral magnitudes in the columns of b are interpolated, and the phase
    # difference between the successive columns of b is calculated; a new
    # column is created in the output array c that preserves this per-step
    # phase advance in each bin.  hop is the STFT hop size, defaults to N/2,
    # where N is the FFT size and b has N/2+1 rows.  hop is needed to
    # calculate the 'null' phase advance expected in each bin.  Note: t is
    # defined relative to a zero origin, so 0.1 is 90% of the first column of
    # b, plus 10% of the second.
    # 2000-12-05 dpwe@ee.columbia.edu

    rows, cols = size(b)
    # note - this isn't necessarily true because the number of rows is rounded
    # when doing the rfft, but in practice (power of 2 frame sizes) it's true
    N = 2*(rows-1)

    # Empty output array
    c = zeros(eltype(b), rows, length(t))

    # Expected phase advance in each bin
    dphi = zeros(div(N,2)+1)
    dphi[2:end] = 2pi*hop/N .* [1:div(N, 2)]

    # Phase accumulator
    # Preset to phase of first frame for perfect reconstruction
    # in case of 1:1 time scaling
    ph = angle(b[:, 1])

    # Append a 'safety' column on to the end of b to avoid problems 
    # taking *exactly* the last frame (i.e. 1*b(:,cols)+0*b(:,cols+1))
    b = hcat(b, zeros(rows,1))

    ocol = 1
    for tt in t
        # Grab the two columns of b
        bcols = b[:, floor(tt)+[1, 2]]
        tf = tt - floor(tt)
        bmag = (1-tf)*abs(bcols[:,1]) + tf*(abs(bcols[:,2]))
        # calculate phase advance
        dp = angle(bcols[:, 2]) - angle(bcols[:, 1]) - dphi
        # Reduce to -pi:pi range
        dp = dp - 2 * pi * round(dp/(2*pi))
        # Save the column
        c[:,ocol] = bmag .* exp(im*ph)
        # Cumulate phase, ready for next frame
        ph = ph + dphi + dp
        ocol = ocol+1
    end

    c
end

function istft{T<:Complex}(d::Array{T}, ftsize=2*(size(d,1)-1), h=0, w=0)
    # istft(d, F, W, H)
    # Inverse short-time Fourier transform.
    # Performs overlap-add resynthesis from the short-time Fourier transform
    # data in d.  Each column of d is taken as the result of an F-point fft;
    # each successive frame was offset by H points (default W/2, or F/2 if
    # W==0). Data is hann-windowed at W pts, or W = 0 gives a rectangular
    # window (default); W as a vector uses that as window.  This version
    # scales the output so the loop gain is 1.0 for either hann-win an-syn
    # with 25% overlap, or hann-win on analysis and rect-win (W=0) on
    # synthesis with 50% overlap.

    s = size(d)
    if s[1] != (ftsize/2)+1
        error("number of rows should be fftsize/2+1")
    end
    cols = s[2]

    if length(w) == 1
        if w == 0
            # special case: rectangular window
            win = ones(ftsize)
        else
            if rem(w, 2) == 0   # force window to be odd-len
                w = w + 1
            end
            halflen = (w-1)/2
            halff = ftsize/2
            halfwin = 0.5 * ( 1 + cos( pi * (0:halflen)/halflen))
            win = zeros(ftsize)
            acthalflen = min(halff, halflen)
            win[(halff+1):(halff+acthalflen)] = halfwin[1:acthalflen]
            win[(halff+1):-1:(halff-acthalflen+2)] = halfwin[1:acthalflen]
            # 2009-01-06: Make stft-istft loop be identity for 25% hop
            # Effect of hanns at both ends is a cumulated cos^2 window (for
            # r = 1 anyway); need to scale magnitudes by 2/3 for
            # identity input/output
            win = 2/3*win
          end
    else
        win = w
    end

    w = length(win)
    # now can set default hop
    if h == 0 
        h = floor(w/2)
    end

    timeframes = irfft(d, ftsize, 1)
    # calculate the length of the output vector
    xlen = ftsize + (cols-1)*h
    x = zeros(xlen)
    #for b in 0:h:(h*(cols-1))
    #    x[(b+1):(b+ftsize)] = x[(b+1):(b+ftsize)] + px.*win
    #end
    for col in 1:cols
        start = (col-1)*h+1
        x[start:start+ftsize-1] = view(x, start:start+ftsize-1) + timeframes[:, col] .* win
    end

    x
end

function pvoc(x, r, n=1024)
    # pvoc(x, r, n)  Time-scale a signal to r times faster with phase vocoder
    # x is an input sound. n is the FFT size, defaults to 1024.  Calculate the
    # 25%-overlapped STFT, squeeze it by a factor of r, inverse spegram.
    # 2000-12-05, 2002-02-13 dpwe@ee.columbia.edu.  Uses pvsample, stft, istft

    # With hann windowing on both input and output,
    # we need 25% window overlap for smooth reconstruction
    hop = div(n, 4)

    # Calculate the basic STFT, magnitude scaled
    X = stft(x, n, hop, hanning(n))

    # Calculate the new timebase samples
    rows, cols = size(X)
    t = 0:r:(cols-2)
    # Have to stay two cols off end because
    #   (a) counting from zero, and
    #   (b) need col n AND col n+1 to interpolate

    # Generate the new spectrogram
    X2 = pvsample(X, t, hop)

    # Invert to a waveform
    y = istft(X2, n, hop, n)
end
