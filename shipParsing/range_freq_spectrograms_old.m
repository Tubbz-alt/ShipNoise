clearvars

% addpath('E:\Code\SPICE-box\SPICE-Detector\io')% I think I moved all
% functions to the shipParsing directory.
% addpath('E:\Code\SPICE-box\SPICE-Detector\funs')
tfDir = 'E:\Code\ShipNoise\shipParsing\TFs'; % folder containing transfer functions
outDir = 'D:\ShippingCINMS_data'; % where the files will save. 
folderTag = 'COP';
mainDir = fullfile(outDir,folderTag);
dirList = dir(fullfile(mainDir,'2*'));
plotOn = 1; % 1 for plots, 0 for no plots

% get list of which tfs go with which deployments.
tfList = importdata('D:\ShippingCINMS_data\CINMS_TFs.csv');

% load(txtFile)
% load(wavFile)
% Bad data ranges:
badDateRanges = [2018-02-16,2018-07-11;
    2015-06-11,	2015-09-01;
    2016-11-09,	2017-02-22];

% Frequency limits used to prune the spectrograms.
minFreq = 10;% in Hz
maxFreq = 3000;% inHz

% Vector of distances to sample at. If you have too many passages with
% bands of no data, this can be adjusted to fix that. For instance, maybe
% vessels don't come closer than 4.5 km, so you're always getting empty
% values for close ranges. In that case, increase 4 to 4.5.
myDistsApproach = (6:-.01:4)*1000; % ends up being in meters
myDistsDepart = (4:.01:6)*1000;
myDists = [myDistsApproach,myDistsDepart];
for iDir = 2:length(dirList)
    
    subDir = fullfile(dirList(iDir).folder,dirList(iDir).name);
    fList = dir(fullfile(subDir,'*.wav'));
    nFiles = size(fList,1);
    
    
    p.DateRegExp = '_(\d{6})_(\d{6})';
    for iFile = 10:nFiles
        soundFile = fullfile(fList(iFile).folder,fList(iFile).name);
        % check if text file exists
        txtFile = strrep(soundFile,'.wav','.txt');
        
        if ~exist(txtFile,'file')
            warning('Could not find file %s, skipping.','txtFile')
            continue
        end
        
        hdr = io_readWavHeader(soundFile,p.DateRegExp);% this just reads the 
        % wav file sample rate, other basic info, and interprets
        % the start time from the file name. You probably have a python
        % script that would do this.
        if sum(hdr.start.dnum>=badDateRanges(:,1) & hdr.start.dnum<=badDateRanges(:,2))
            disp('Event falls within bad date range. Skipping.\n')
            continue
        end
        wavData = io_readWav(soundFile,hdr,...
            0,(hdr.end.dnum-hdr.start.dnum)*24*60*60,...
            'Units','s','Normalize','unscaled');
        
        % get info from text file to be able to calculate range.
        textData = importdata(txtFile);
        
        [siteName,~] = regexp(textData.textdata{1,1},'HARPSite=(\w*)','tokens','match');
        siteName = siteName{1};
        
        k1Idx = find(~cellfun(@isempty,strfind((textData.textdata(:,1)),'HARPLat'))==1);
        if ~isempty(k1Idx)
            [k1,~]= regexp(textData.textdata{k1Idx,1},'HARPLat=(\d*\.\d*)','tokens','match');
            HARPLat = str2double(cell2mat(k1{1,1}));
        end
        k2Idx = find(~cellfun(@isempty,strfind((textData.textdata(:,1)),'HARPLon'))==1);
        if ~isempty(k2Idx)
            [k2,~]= regexp(textData.textdata{k2Idx,1},'HARPLon=(-\d*\.\d*)','tokens','match');
            HARPLon = str2double(cell2mat(k2{1,1}));
        end
        
        k4Idx = find(~cellfun(@isempty,strfind((textData.textdata(:,1)),'CPATime'))==1);
        if ~isempty(k4Idx)
            [k4,~]= regexp(textData.textdata{k4Idx,1},'CPATime\[UTC\]=(.*)','tokens','match');
            CPATime = datenum(char(k4{1,1}));
        end
        
        k5Idx = find(~cellfun(@isempty,strfind((textData.textdata(:,1)),'CPADistance'))==1);
        if ~isempty(k5Idx)
            [k5,~]= regexp(textData.textdata{k5Idx,1},'CPADistance\[m\]=(\d*)','tokens','match');
            CPADist = str2num(char(k5{1,1}));
        end
        
        k6Idx = find(~cellfun(@isempty,strfind((textData.textdata(:,1)),'UTC'))==1);
        if ~isempty(k6Idx)
            timeSteps = datenum(textData.textdata(k6Idx(end)+1:end,1));
        end
        
        % get TF
        tfIdx = find(~cellfun(@isempty,strfind(tfList.textdata(:,1),siteName)));
        tfNum = tfList.data(tfIdx-1);
        tfFolder = dir(fullfile(tfDir,[num2str(tfNum),'*']));
        %tfFile = dir(fullfile(tfFolder.folder,tfFolder.name,'*.tf'));
        tfFile = dir(fullfile(tfFolder.folder,tfFolder.name));
 
        if isempty(tfFile)
            error('missing tf file')
        end
        
        %         B = HARPLat;r1 = 6378.137;r2 = 6371.001;
        %         R = sqrt([(r1^2 * cos(B))^2 + (r2^2 * sin(B))^2 ] / [(r1 * cos(B))^2 + (r2 * sin(B))^2]); % radius of earth at HARP lat
        %         distH2Sdeg = sqrt((HARPLat-textData.data(:,1)).^2+(HARPLon-textData.data(:,2)).^2);
        %         distH2Skm = deg2km(distH2Sdeg,R);
        %
        [xRange,yRange] = latlon2xy(HARPLat,HARPLon,textData.data(:,1),textData.data(:,2));
        range1  = sqrt(xRange.^2+yRange.^2);
        %         figure(2);clf
        %         plot(timeSteps,abs(range1/1000),'*')
        %         hold on
        %         plot(timeSteps,distH2Skm,'*r')
        %
        % plot(timeSteps,ones(size(xyRanges))*CPADist/1000,'-k')
        % datetick
        
        
        % get times from textData.textdata
        % approach
        [~,cpaIdx] = min(abs(timeSteps-CPATime));
        [uRange1,ia,ic] = unique(range1(1:cpaIdx),'stable');
        uTimeStepsTemp = timeSteps(1:cpaIdx);
        uTimeSteps = uTimeStepsTemp(ia);
        timesToSample = interp1(uRange1,uTimeSteps,myDistsApproach);
        distSpecApproach = nan(length(myDistsApproach),5001);
        myDistSpecImag = [];
        uppc = [];
        for iDist = 1:length(myDistsApproach)
            
            myTimeIdx = round(hdr.fs*((timesToSample(iDist)-hdr.start.dnum)*60*60*24));
            if isnan(myTimeIdx) || myTimeIdx<1
                continue
            end
            myData = wavData(max(myTimeIdx-5000,1):min(myTimeIdx+5000-1,length(wavData)));
            if length(myData)<10000
                myData = [myData;zeros(10000-length(myData),1)];
            end
            [~,f,t,psd] = spectrogram(myData,hanning(10000),0,10000,hdr.fs,'psd');
            if isempty(uppc)&& ~isempty(f)
                [~, uppc] = fn_tfMap(fullfile(tfFile.folder,tfFile.name),f);
                fKeep = f;
            end
            sdBApproach = 10*log10(psd);
            if ~isempty(sdBApproach)
                distSpecApproach(iDist,:) = (sdBApproach+uppc)';
            end
        end
        
        % departure
        [~,cpaIdx] = min(abs(timeSteps-CPATime));
        [uRange1,ia,ic] = unique(range1(cpaIdx+1:end),'stable');
        uTimeStepsTemp = timeSteps(cpaIdx+1:end);
        uTimeSteps = uTimeStepsTemp(ia);
        timesToSampleD = interp1(uRange1,uTimeSteps,myDistsDepart);
        % timesToSampleD = interp1(range1(cpaIdx+1:end),timeSteps(cpaIdx+1:end),myDistsDepart);
        distSpecDepart= nan(length(myDistsDepart),5001);
        uppc = [];
        for iDist = 1:length(myDistsDepart)
            
            myTimeIdx = round(hdr.fs*((timesToSampleD(iDist)-hdr.start.dnum)*60*60*24));
            if isnan(myTimeIdx) || myTimeIdx<1
                continue
            end
            myData = wavData(max(myTimeIdx-5000,1):min(myTimeIdx+5000-1,length(wavData)));
            if length(myData)<10000
                myData = [myData;zeros(10000-length(myData),1)];
            end
            [~,f,t,psd] = spectrogram(myData,hanning(10000),0,10000,hdr.fs,'psd');
            if isempty(uppc)&& ~isempty(f)
                [~, uppc] = fn_tfMap(fullfile(tfFile.folder,tfFile.name),f);
                fKeep = f;
            end
            sdBDepart = 10*log10(psd);
            if ~isempty(sdBDepart)
                distSpecDepart(iDist,:) = (sdBDepart+uppc)';
            end
            
            
        end
        
        [~,fMinIdx] = min(abs(fKeep-minFreq));
        [~,fMaxIdx] = min(abs(fKeep-maxFreq));
        fKeep = fKeep(fMinIdx:fMaxIdx);
        
        finalDistSpec = [distSpecApproach(:,fMinIdx:fMaxIdx);distSpecDepart(:,fMinIdx:fMaxIdx)]';
        finalDistSpec_floored = max(finalDistSpec,40);% same thing but floored to what seems 
        % like a reasonable minimum value based on visual inspection.
        
        if plotOn
            figure(1);clf
            subplot(1,2,1)
            imagesc(finalDistSpec_floored);set(gca,'ydir','normal');colormap(jet);colorbar
            roundLabels = find(mod(myDists,500)==0);
            xtickLocs = set(gca,'xtick',roundLabels);
            set(gca,'XTickLabel',myDists(roundLabels)/1000);
            xlabel('Range (km)')
            ylabel('Frequency (Hz)')
            title('Range-Frequency')
            caxis(gca,[40,100])
            subplot(1,2,2)
            spectrogram(wavData,1000,0,1000,hdr.fs,'psd','yaxis'); % sanity check to compare time freq vs range freq.
            colormap(jet);
            ylim([minFreq,maxFreq]./1000)
            caxis(gca,[-30,25])
            title('Time-Frequency (noTF)')
            text(-.65,1.05,0,datestr(hdr.start.dnum),'units','normalized','FontSize',16)
            1;
        end
        [~,nameStem,~] = fileparts(soundFile);
        outFileName = [nameStem,'_rangeFreq.mat'];
        freqHz = fKeep;
        % output file in netcdf format
        save(fullfile(subDir,outFileName),'freqHz','finalDistSpec','finalDistSpec_floored','myDists','-v7.3')
    end
end


