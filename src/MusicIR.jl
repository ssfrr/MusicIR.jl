module MusicIR

using DSP

export frame, stft, tcif, specgram, tcifgram
# from dpwe.jl:
export pvoc, istft
include("dpwe.jl")

function frame(sig::AbstractArray, n::Integer, hop::Integer=n)
    overlap = n - hop
    nframes = div(length(sig) - overlap - 1, hop) + 1
    frames = similar(sig, typeof(sig[1]), n, nframes)

    for f in 0:(nframes-1)
        framestart = f * hop
        for i in 1:n
            if framestart + i <= length(sig)
                frames[i, f+1] = sig[framestart + i]
            else
                frames[i, f+1] = 0
            end
        end
    end

    frames
end

function stft(arr::AbstractArray, n::Integer=1024, hop::Integer=div(n,2), window=hanning(n))
    frames = frame(arr, n, hop)
    windowed = similar(frames)
    for j in 1:size(windowed, 2)
        for i in 1:size(windowed, 1)
            windowed[i, j] = frames[i, j] * window[i]
        end
    end
    spec = rfft(windowed, 1)
end

function specgram(arr::AbstractArray, n::Integer=1024, hop::Integer=div(n,2), window=hanning(n), sr=44100)
    frames = stft(arr, n, hop, window)
    extent=[0, size(frames, 2)*hop/sr, 0, sr/2]
    imshow(log(1+1000*abs(frames)), aspect=:auto, origin=:lower, interpolation="none", extent=extent)
end

phasewrap(x) = mod2pi(x+pi) - pi

function tcif(sig::AbstractArray, n::Integer, samplerate::Real, hop::Integer=div(n,2), window=hanning(n))
    # Take the STFT and a 1-sample delayed STFT so we can get phase differences without aliasing
    frames = stft(sig[1:end-1], n, hop)
    delframes = stft(sig[2:end], n, hop)

    # create an array to hold the frequency data, with a row for each
    # data point, and 3 columns for time, frequency, magnitude
    tcif_data = Array(Float64, (size(frames, 1)-1) * size(frames, 2), 3)

    # calculate the expected phase offset for each bin
    exp_phase = [2pi * (k-1)*1/n  for k in 1:n]
    # get dt and dω to use in the finite difference calculation
    dt = 1/samplerate
    dω = samplerate/n*2pi

    j = 1
    for i in 1:size(frames, 2)
        t = i * hop / samplerate
        for bin in 1:(n/2)
            dϕ = angle(delframes[bin, i]) - angle(frames[bin, i])
            freq = (phasewrap(dϕ - exp_phase[bin]) + exp_phase[bin]) / (2pi*dt)
            offset = phasewrap(angle(frames[bin, i]) - angle(frames[bin+1, i])) / dω

            tcif_data[j, 1] = t + offset
            tcif_data[j, 3] = (abs(frames[bin, i]) + abs(delframes[bin, i])) / 2
            tcif_data[j, 2] = freq
            j += 1
        end
    end

    tcif_data
end

function tcifgram(sig::AbstractArray, n::Integer, sr::Real, hop::Integer=div(n,2), window=hanning(n))
    crange = [AlphaColorValue(RGB(0,0,0), 0.0), AlphaColorValue(RGB(0,0,0), 1.0)]
    cmap = ColorMap("alphablend", crange)

    tcif_data = tcif(sig, n, sr, hop)
    scatter(tcif_data[:, 1], tcif_data[:, 2], s=2, c=log(1+100*tcif_data[:, 3]), cmap=cmap, linewidths=0)
    ylim(0, sr/2)
    xlim(0, length(sig)/sr)
end

end # module
