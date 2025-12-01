% AUTHOR: Abdelrahman Abdelaziz Mohamed (E-mail: abdu.abdelaziz46@gmail.com)
%
% DATE: 26/10/2025
%
% DESCRIPTION: This MATLAB function extracts video frames either by loading them from a pre-existing folder 
%              or by reading and saving them from the video file. It optimizes processing time by reusing 
%              previously extracted frames when available. The function provides two output formats suitable 
%              for different video processing applications and uses parallel processing for efficient frame saving.
%
% Code Overview --> The function performs the following key operations:
%                       - Checks for existing extracted frames folder to avoid redundant processing
%                       - If frames exist: loads them directly with natural sorting
%                       - If frames don't exist: reads video, extracts frames sequentially, saves them in parallel
%                       - Returns frames in both struct array and cell array formats for flexibility
%
% Step-by-Step Functionality 
% 1. Output Folder Preparation:
%    - Extracts video filename and creates corresponding folder path in 'Extracted_Frames'
%    - Initializes Video_Structure with basic video metadata
%
% 2. Existing Frame Detection and Loading:
%    - If folder exists: searches for 'frame_*.png' files
%    - Uses natural sorting to handle frame numbering correctly (frame_10 after frame_9)
%    - Loads frames into memory while preserving original video frame rate
%
% 3. Video Reading and Frame Extraction (when no existing frames):
%    - Creates VideoReader object to access video properties
%    - Extracts technical specifications: resolution, duration, frame rate
%    - Reads frames sequentially into memory (MATLAB VideoReader limitation)
%    - Calculates actual vs estimated frame count for accuracy
%
% 4. Parallel Frame Saving:
%    - Uses parfor loop to save frames as PNG images simultaneously
%    - Implements consistent naming convention: frame_0001.png, frame_0002.png, etc.
%    - Maintains frame quality with PNG format preservation
%
% 5. Output Format Preparation:
%    - Video_Structure: Struct array with 'cdata' and 'colormap' fields (compatible with movie() function)
%    - Frame_Data: Cell array containing only frame image data (simpler format for processing)
%
% INPUT PARAMETERS:
%   - File_Name: Full path to the video file (supports formats readable by VideoReader)
%
% OUTPUT:
%   - Frame_Data: Cell array where each cell contains frame image data (height × width × 3 RGB)
%   - Video_Structure: Struct array with fields:
%        * cdata: Frame image data
%        * colormap: Empty array ([]), reserved for indexed images
%        Additional metadata in main structure:
%        * videoName: Original video filename without extension
%        * videoPath: Full path to source video
%        * frameRate: Original video frame rate (Hz)
%        * height: Video frame height (pixels)
%        * width: Video frame width (pixels) 
%        * duration: Video duration (seconds)
%        * actualFrames: Actual number of extracted frames
%
% Notes for the Developer
% Dependencies:
%   - Requires VideoReader, imread, imwrite functions
%   - Uses Parallel Computing Toolbox for parfor (frame saving)
%   - Includes custom sort_nat function for natural filename sorting
%
% Limitations and Considerations:
%   - Video reading is sequential due to VideoReader limitations (cannot be parallelized)
%   - Assumes RGB video format; grayscale/indexed color not specifically handled
%   - Frame rate detection may fall back to 30 fps if original video cannot be read
%   - Memory intensive for long videos - all frames loaded into memory simultaneously
%
% Performance Optimization:
%   - Avoids redundant frame extraction by checking existing folders
%   - Parallelizes disk I/O operations during frame saving
%   - Natural sorting ensures correct frame sequence regardless of numbering
%
% Customization Points:
%   - Output image format: Modify imwrite parameters in parfor loop
%   - Frame naming: Change sprintf format in frameFileName generation
%   - Output folder structure: Modify outputFolder path construction
%   - Metadata collection: Add additional video properties to Video_Structure
%
% Error Handling:
%   - Throws error if existing folder contains no valid frame images
%   - Falls back to default frame rate if original video properties unavailable
%   - Handles variable frame counts between estimated and actual values



function [Frame_Data, Video_Structure] = Grab_Video_Frames_par2(File_Name)

    % Extract the filename without extension from the full video path
    % Create a path for a subfolder to save the extracted frames
    [~, videoName, ~] = fileparts(File_Name);
    outputFolder = fullfile('Extracted_Frames', videoName);

    % Initialize Video_Structure with basic info
    Video_Structure = struct();
    Video_Structure.videoName = videoName;
    Video_Structure.videoPath = File_Name;

    % If the folder already exists, load the frames from there
    if exist(outputFolder, 'dir')
        fprintf('\nFrame folder already exists. Loading frames from "%s"...\n', outputFolder);

        imageFiles = dir(fullfile(outputFolder, 'frame_*.png')); % Find all files starting with frame_ and ending with .png
        numFrames = numel(imageFiles); % Count how many frames there are
        if numFrames == 0 % If the folder exists but is empty, throw an error
            error('The folder "%s" exists but contains no frame images.', outputFolder);
        end

        % Sort by name (frame_0001.png, frame_0002.png, ...)
        imageFiles = sort_nat({imageFiles.name});
        
        % Initialize a cell array and load each frame image into memory
        Video_Frames = cell(1, numFrames);
        for k = 1:numFrames
            framePath = fullfile(outputFolder, imageFiles{k});
            Video_Frames{k} = imread(framePath);
        end

        % Try to get frame rate from video file for consistency
        try
            Video_Properties = VideoReader(File_Name);
            Video_Structure.frameRate = Video_Properties.FrameRate;
            fprintf('Frame rate from original video: %.2f fps\n', Video_Structure.frameRate);
        catch
            % If cannot read video file, use default or try to get from existing info
            Video_Structure.frameRate = 30; % Default fallback
            fprintf('Using default frame rate: %.2f fps\n', Video_Structure.frameRate);
        end

    else
        % Folder does not exist: extract frames from the video
        fprintf('\nReading video and extracting frames...\n');

        Video_Properties = VideoReader(File_Name); % Use VideoReader to access properties and frames
        % Extract video properties: height, width, duration, and fps
        Video_Height = Video_Properties.Height;
        Video_Width = Video_Properties.Width;
        Video_Duration = Video_Properties.Duration;
        Video_FrameRate = Video_Properties.FrameRate; % Keep original frame rate without rounding

        % Save frame rate in Video_Structure
        Video_Structure.frameRate = Video_FrameRate;
        Video_Structure.height = Video_Height;
        Video_Structure.width = Video_Width;
        Video_Structure.duration = Video_Duration;

        % Estimate number of frames
        Estimated_Num_Frames = floor(Video_Duration * Video_FrameRate);

        % Display info
        fprintf('\nResolution: %d x %d\n', Video_Width, Video_Height);
        fprintf('Duration: %.2f seconds\n', Video_Duration);
        fprintf('Frame rate: %.2f fps\n', Video_FrameRate);
        fprintf('Estimated number of frames: %d\n', Estimated_Num_Frames);

        % Create the folder to save frames
        mkdir(outputFolder);

        % Load frames
        fprintf('\nReading video into memory...\n');
        Video_Frames = cell(1, Estimated_Num_Frames);
        i = 1;
        while hasFrame(Video_Properties)
            Video_Frames{i} = readFrame(Video_Properties);
            i = i + 1;
        end
        % In case the actual number of frames is smaller
        Video_Frames = Video_Frames(1:i-1);
        Video_Structure.actualFrames = i-1;

        % Save each frame to disk in parallel, named like frame_0001.png, frame_0002.png, etc.
        fprintf('Saving frames in parallel...\n');
        parfor k = 1:numel(Video_Frames)
            frame = Video_Frames{k};
            if ~isempty(frame) % Check that the image is not empty (to avoid issues with corrupted or missing frames)
                % Build the file path with a name like frame_0001.png
                % 04d means "use 4 digits with leading zeros"
                frameFileName = fullfile(outputFolder, sprintf('frame_%04d.png', k));
                imwrite(frame, frameFileName); % Save the frame to disk
            end
        end

        fprintf('\nFrames saved in "%s".\n', outputFolder);
    end

    % Create the output structure in the required format
    Output_Structure = struct('cdata', [], 'colormap', []);
    % Create an empty structure with two fields:
    %   cdata: will contain the frame data (the image itself)
    %   colormap: left empty ([]) because frames are RGB images, not indexed (which would require a colormap)
    for k = 1:numel(Video_Frames)
        Output_Structure(k).cdata = Video_Frames{k}; % Assign the k-th frame to the structure field `cdata`
        % So, Output_Structure(1).cdata will contain the first frame, and so on
        Output_Structure(k).colormap = []; % Explicitly set colormap to empty; not used with RGB images
    end

    Frame_Data = {Output_Structure.cdata};
    % Create a cell array containing all frames, extracted from the cdata field of the structure
    % Equivalent to:
    % Frame_Data = {Output_Structure(1).cdata, Output_Structure(2).cdata, ...};

end

% Le funzioni sort_nat rimangono invariate
function sorted = sort_nat(files)
    [~, idx] = sort_nat_internal(files);
    sorted = files(idx);
end

function [sorted, idx] = sort_nat_internal(c)
    expr = '\d+';  % Regex to find numbers
    [~, idx] = sort(cellfun(@(s) sscanf(regexp(s, expr, 'match', 'once'), '%d'), c));
    sorted = c(idx);
end