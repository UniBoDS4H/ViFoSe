% AUTHOR: Abdelrahman Abdelaziz Mohamed (E-mail: abdu.abdelaziz46@gmail.com)
%
% DATE: 25/07/2025
%
% DESCRIPTION: This MATLAB function performs video stabilization using gradient correlation in parallel. It aligns all video frames to a user-specified
%               reference frame by estimating translational transformations via imregcorr. The aligned frames are then compiled into a new, stabilized output video.
%               The function is optimized using MATLAB's parfor loop to speed up processing on systems with multiple CPU cores.
%
% Code Overview
% The function performs the following tasks:
%   - Accepts a cell array of video frames, an output folder path, a frame rate, and a reference frame index.
%   - Applies translation-only registration of each frame to the reference using gradient correlation.
%   - Executes the alignment in parallel to improve performance.
%   - Writes the stabilized frames to a new .avi video using the Motion JPEG codec.
%
% Step-by-Step Functionality
%   - Reference Frame Initialization:
%       - Extracts the reference frame (fixed_image) and creates a spatial reference object (Rfixed_image) using imref2d, which will be
%           used to ensure all aligned frames have the same size and orientation.
%   - Preallocation:
%       - Initializes a cell array stabilizedFrames to store the aligned frames. The reference frame is directly assigned without processing.
%   - Parallel Stabilization Loop (parfor):
%       - Iterates over all video frames except the reference.
%       - For each frame:
%           - Estimates a translational geometric transformation to align it with the reference frame using imregcorr.
%           - Applies the transformation using imwarp and stores the stabilized frame.
%   - Video Writing:
%       - Creates the output video file in the specified folder, with filename 'stabilized_GRADIENT_output.avi'.
%       - Uses the Motion JPEG AVI format and assigns the specified frame rate.
%       - Writes all frames (including the unchanged reference) into the video sequentially using writeVideo.
%
% Notes for the Developer
% Dependencies: The Image Processing Toolbox is required for imregcorr and imwarp.
% Customization:
%   - The transformation model is currently set to translation only, suitable for small camera shifts. For more complex motion, consider rigid or affine.
%   - To support other formats (e.g., .mp4), modify the VideoWriter settings accordingly.
% Performance:
%   - Uses parfor to parallelize the stabilization, which significantly reduces processing time on multi-core CPUs.
%   - Ensure that the Parallel Computing Toolbox is available and a parallel pool is active (automatically started in newer MATLAB versions).
% Error Handling:
% - No explicit error handling is included. Consider adding checks for missing frames or failed transformations in future versions.



function app_stabilizer_gradientCorrelation_par(Frame_Data, outputFolder, fps, referenceFrame, inputFolder)
% Video stabilization using gradient correlation - parallel version

numFrames = length(Frame_Data);
fixed_image = Frame_Data{referenceFrame};
Rfixed_image = imref2d(size(fixed_image));

% Preallocate cell array for stabilized frames
stabilizedFrames = cell(1, numFrames);
stabilizedFrames{referenceFrame} = fixed_image;

% Perform stabilization in parallel
parfor i = 1:numFrames
    if i == referenceFrame
        continue;
    end
    moving = Frame_Data{i};
    tformEstimate = imregcorr(moving, fixed_image, 'translation');
    aligned_image = imwarp(moving, tformEstimate, 'OutputView', Rfixed_image);
    stabilizedFrames{i} = aligned_image;
end

% Create the output video file name
[~, name] = fileparts(inputFolder);  % Use folder name
outputVideoName = [name '_stabilized_GRADIENT.mp4'];
outputVideoPath = fullfile(outputFolder, outputVideoName);
outputVideo = VideoWriter(outputVideoPath, 'MPEG-4');
outputVideo.FrameRate = fps;
open(outputVideo);

% Write all frames to the video
for i = 1:numFrames
    writeVideo(outputVideo, stabilizedFrames{i});
end

close(outputVideo);
end