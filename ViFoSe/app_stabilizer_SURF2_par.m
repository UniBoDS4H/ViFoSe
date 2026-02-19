% AUTHOR: Abdelrahman Abdelaziz Mohamed (E-mail: abdu.abdelaziz46@gmail.com)
%
% DATE: 15/01/2026
%
% DESCRIPTION: This MATLAB function stabilizes a video by aligning each frame to a user-selected reference frame using the SURF (Speeded-Up Robust Features) algorithm.
%               The function detects and matches SURF features between the reference frame and each other frame to compute an affine geometric transformation.
%               It then applies this transformation to align each frame to the reference frame, effectively stabilizing the video.
%               The stabilized frames are saved as a new video file in the specified output folder.
%
% Code Overview
%   - Receives as input the cell array of frames (Frame_Data), the output folder path (outputFolder), the desired frames per second (fps),
%       and the index of the reference frame (referenceFrame).
%   - Converts the reference frame to grayscale and detects SURF features and descriptors in it.
%   - Initializes an output array to store stabilized frames, assigning the reference frame itself as already stabilized.
%   - Defines a fixed output coordinate system (outputView) based on the size of the reference frame to ensure all frames are aligned to the same dimensions.
%   - Iterates in parallel (parfor) over all frames except the reference frame:
%       - Converts the current frame to grayscale.
%       - Detects SURF features and extracts their descriptors.
%       - Matches the current frame’s SURF features to those in the reference frame.
%       - If enough matching points (≥ 3) exist, estimates an affine geometric transform aligning the current frame to the reference.
%       - Applies the transform to warp the current frame into alignment, storing the stabilized frame.
%       - If matching fails or an error occurs, the original frame is kept as fallback.
%   - After processing all frames, writes the stabilized frames sequentially into a new MPEG-4 video file at the specified frame rate and saves it in the output folder.
%
% Step-by-Step Functionality
%   - Input Parsing: Receives frame data, output folder path, fps, and reference frame index.
%   - Reference Frame Preparation: Converts reference frame to grayscale and detects/extracts SURF features and valid points.
%   - Stabilization Loop: For each frame (except reference):
%       - Convert to grayscale.
%       - Detect and extract SURF features.
%       - Match features with reference frame.
%       - If sufficient matches, estimate affine transformation and warp frame accordingly.
%       - Store stabilized frame or fallback to original if error occurs.
%   - Output Video Saving: Initializes a VideoWriter object, sets frame rate, and writes all stabilized frames sequentially. Closes the video file upon completion.
%
% Notes for the Developer
%   - Dependencies: Requires MATLAB Computer Vision Toolbox for SURF feature detection, extraction, and matching.
%   - Parallelization: Uses parfor to speed up frame stabilization but avoids processing the reference frame to prevent redundancy.
%   - Robustness: Implements fallback to original frames in case transformation estimation fails, improving stability of the function.
%   - Customization: Output video format, frame rate, and feature matching parameters can be adjusted for specific needs.
%   - Output Dimensions: All frames are aligned using a fixed coordinate reference to ensure consistent video dimensions.



function app_stabilizer_SURF2_par(Frame_Data, outputFolder, fps, referenceFrame, inputFolder)

    numFrames = numel(Frame_Data);

    % Reference frame
    refFrame = Frame_Data{referenceFrame};
    refGray = im2gray(refFrame);

    % SURF point detection in the reference frame
    refPoints = detectSURFFeatures(refGray);
    [refFeatures, refValidPoints] = extractFeatures(refGray, refPoints);

    % Preallocate the stabilized frames
    stabilizedFrames = cell(1, numFrames);
    stabilizedFrames{referenceFrame} = refFrame;

    % Output view (constant dimensions for all frames)
    outputView = imref2d(size(refFrame));

    % Parallel loop
    parfor i = 1:numFrames
        if i == referenceFrame
            continue;
        end

        % Current frame
        currentFrame = Frame_Data{i};
        currentGray = im2gray(currentFrame);

        % SURF point detection
        currPoints = detectSURFFeatures(currentGray);
        [currFeatures, currValidPoints] = extractFeatures(currentGray, currPoints);

        % Feature matching between current frame and reference frame
        indexPairs = matchFeatures(currFeatures, refFeatures, 'Unique', true);

        matchedCurr = currValidPoints(indexPairs(:, 1));
        matchedRef  = refValidPoints(indexPairs(:, 2));

        % If enough points are matched, compute transformation and stabilize
        if length(matchedCurr) >= 3
            try
                tform = estimateGeometricTransform2D(matchedCurr, matchedRef, 'affine');
                stabilizedFrame = imwarp(currentFrame, tform, 'OutputView', outputView);
                stabilizedFrames{i} = stabilizedFrame;
            catch
                stabilizedFrames{i} = currentFrame; % fallback if error occurs
            end
        else
            stabilizedFrames{i} = currentFrame; % fallback if not enough matches
        end
    end

    % Save the stabilized video
    if isunix || ispc || ismac
        % METHOD 1: Extract the last folder name from the path using string splitting
        % This handles folder names with dots correctly
        pathParts = strsplit(inputFolder, filesep);
        if ~isempty(pathParts)
            folderName = pathParts{end};
        else
            folderName = inputFolder;
        end
                     
        % Remove trailing filesep if present
        folderName = strrep(folderName, filesep, '');
        
        % Debug: Display the extracted folder name
        fprintf('Extracted folder name: %s\n', folderName);
        
        % If folderName is still empty, use a default name
        if isempty(folderName)
            folderName = 'stabilized_video';
        end
        
        % Build the output video name
        if isunix
            outputVideoName = [folderName '_stabilized_SURF.avi'];
            outputVideoPath = fullfile(outputFolder, outputVideoName);
            writer = VideoWriter(outputVideoPath, 'Motion JPEG AVI');
        else % ispc || ismac
            outputVideoName = [folderName '_stabilized_SURF.mp4'];
            outputVideoPath = fullfile(outputFolder, outputVideoName);
            writer = VideoWriter(outputVideoPath, 'MPEG-4');
        end
        
        writer.FrameRate = fps;
        open(writer);

        for i = 1:numFrames
            writeVideo(writer, stabilizedFrames{i});
        end
        
        close(writer);
        fprintf('Stabilized video saved as: %s\n', outputVideoPath);
        
    else
        disp('Platform not supported');
    end
end