classdef UI_UDP_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        ErrorLamp                matlab.ui.control.Lamp
        ErrorLampLabel           matlab.ui.control.Label
        RunButton                matlab.ui.control.StateButton
        TabGroup                 matlab.ui.container.TabGroup
        PosControlTab            matlab.ui.container.Tab
        ResetButton              matlab.ui.control.Button
        PosEditField             matlab.ui.control.NumericEditField
        PosEditFieldLabel        matlab.ui.control.Label
        YEditField               matlab.ui.control.NumericEditField
        YEditFieldLabel          matlab.ui.control.Label
        XEditField               matlab.ui.control.NumericEditField
        XEditFieldLabel          matlab.ui.control.Label
        KpEditField              matlab.ui.control.NumericEditField
        KpEditFieldLabel         matlab.ui.control.Label
        KiEditField              matlab.ui.control.NumericEditField
        KiEditFieldLabel         matlab.ui.control.Label
        KdEditField              matlab.ui.control.NumericEditField
        KdEditFieldLabel         matlab.ui.control.Label
        SpdControlTab            matlab.ui.container.Tab
        ResetButton_2            matlab.ui.control.Button
        SpeedfbEditField         matlab.ui.control.NumericEditField
        SpeedfbEditFieldLabel    matlab.ui.control.Label
        SpdrpmRPMIndicator       Aero.ui.control.RPMIndicator
        SpdrpmRPMIndicatorLabel  matlab.ui.control.Label
        KiEditField_2            matlab.ui.control.NumericEditField
        KiEditField_2Label       matlab.ui.control.Label
        KpEditField_3            matlab.ui.control.NumericEditField
        KpEditField_3Label       matlab.ui.control.Label
        KdEditField_2            matlab.ui.control.NumericEditField
        KdEditField_2Label       matlab.ui.control.Label
        SpeedsetEditField        matlab.ui.control.NumericEditField
        SpeedsetEditFieldLabel   matlab.ui.control.Label
        StartStopLamp            matlab.ui.control.Lamp
        StartStopLampLabel       matlab.ui.control.Label
        UIAxes_2                 matlab.ui.control.UIAxes
        UIAxes                   matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        VisObj          % FourBar_Visualizer objesi
        UpdateTimer     % Animasyon zamanlayıcısı
        uPortRx         % Okuma (Dinleme) Portu
        uPortTx         % Gönderme Portu
        
        Target_X = 0;
        Target_Y = 0;
        Target_RPM = 0;
        Control_Mode = 0; % 0 = Position, 1 = Speed
        Start_Stop = 0;   % 0 = Stop, 1 = Start

        %Kesme (Interrupt) ile Timer'ın ortak hafızası
        Current_Theta = 0;
        Current_Omega = 0;

        Reset_Flag = 0;

        % --- GRAFİK DEĞİŞKENLERİ ---
        FbLine           % Feedback çizgisi (Açı veya Hız)
        RefLine          % Referans çizgisi (Hedef)
        TimeData = []    % Zaman ekseni
        PlotFbData = []  % Feedback verisi
        PlotRefData = [] % Referans verisi
        StartTime
    end
    
    methods (Access = private)
        % --- 1. ZAMANLAYICI DÖNGÜSÜ (Veri Okuma, Animasyon ve GÖNDERME) ---
        function animationLoop(app)
            % 1. KORUMA KALKANI: Eğer arayüz kapatılıyorsa veya silindiyse hemen çık!
            if ~isvalid(app) || ~isvalid(app.UIFigure) || ~isvalid(app.UIAxes_2)
                return;
            end
            
            try
                % --- ASIL KODLAR BURAYA ---
                app.Target_X = app.VisObj.target_XY(1);
                app.Target_Y = app.VisObj.target_XY(2);
                
                app.XEditField.Value = app.Target_X;
                app.YEditField.Value = app.Target_Y;
                
                app.VisObj.updateAnimation(app.Current_Theta);
                Speed_rpm = app.Current_Omega * (30/pi);
                app.SpdrpmRPMIndicator.Value = abs(Speed_rpm);
                app.SpeedfbEditField.Value = Speed_rpm;
                wrapped_deg = mod(rad2deg(app.Current_Theta), 360);
                app.PosEditField.Value = wrapped_deg;

                % --- CANLI GRAFİK (REAL-TIME PLOT) ---
                currentTime = toc(app.StartTime);
                app.TimeData(end+1) = currentTime;
                
                if app.Control_Mode == 0
                    % POZİSYON MODU
                    app.PlotFbData(end+1) = wrapped_deg;
                    app.PlotRefData(end+1) = NaN;
                    maxY = 360; 
                else
                    % HIZ MODU
                    currentSetSpeed = app.SpeedsetEditField.Value;
                    app.PlotFbData(end+1) = Speed_rpm;
                    app.PlotRefData(end+1) = currentSetSpeed;
                    maxY = max(currentSetSpeed * 1.3, 10); 
                end
                
                windowSize = 100; 
                if length(app.TimeData) > windowSize
                    app.TimeData = app.TimeData(end-windowSize+1 : end);
                    app.PlotFbData = app.PlotFbData(end-windowSize+1 : end);
                    app.PlotRefData = app.PlotRefData(end-windowSize+1 : end);
                end
                
                app.FbLine.XData = app.TimeData;
                app.FbLine.YData = app.PlotFbData;
                app.RefLine.XData = app.TimeData;
                app.RefLine.YData = app.PlotRefData;
                
                if app.TimeData(end) > 0
                    app.UIAxes_2.XLim = [app.TimeData(1), app.TimeData(end) + 0.1];
                end
                app.UIAxes_2.YLim = [0, maxY];
                % -------------------------------------------

                %drawnow limitrate;
                
                if app.RunButton.Value == 1
                    app.sendDataPacket();
                end
                
                if app.Start_Stop == 1
                    app.StartStopLamp.Color = 'g'; % Çalışıyor (Running)
                else
                    app.StartStopLamp.Color = 'r'; % Durdu (Stopped)
                end

            catch ME
                % 2. X-RAY CİHAZI: Eğer gizli bir hata varsa ekrana bas ve Timer'ı durdur!
                disp('!!! ANIMATION LOOP İÇİNDE GİZLİ HATA YAKALANDI !!!');
                disp(ME.message);
                if ~isempty(ME.stack)
                    disp(['Hatanın Çıktığı Satır: ', num2str(ME.stack(1).line)]);
                end
                

                % Sistemi daha fazla çökertmemek için döngüyü durdur
                if isvalid(app.UpdateTimer)
                    stop(app.UpdateTimer);
                end
            end

        end
        
        % --- VERİ GÖNDERME ---
        function sendDataPacket(app)
            if app.Control_Mode == 0 % Pozisyon Modu
                Kp = single(app.KpEditField.Value);
                Ki = single(app.KiEditField.Value);
                Kd = single(app.KdEditField.Value);
                trgX = single(app.XEditField.Value);
                trgY = single(app.YEditField.Value);
                trgRpm = single(0);
            else % Hız Modu
                Kp = single(app.KpEditField_3.Value);
                Ki = single(app.KiEditField_2.Value);
                Kd = single(app.KdEditField_2.Value);
                trgX = single(app.Target_X);
                trgY = single(app.Target_Y);
                trgRpm = single(app.SpeedsetEditField.Value);
            end
            
            b_Kp   = typecast(Kp, 'uint8');
            b_Ki   = typecast(Ki, 'uint8');
            b_Kd   = typecast(Kd, 'uint8');
            b_TrgX = typecast(trgX, 'uint8');
            b_TrgY = typecast(trgY, 'uint8');
            b_TrgR = typecast(trgRpm, 'uint8');
            b_Mode = typecast(uint8(app.Control_Mode), 'uint8');
            b_StSt = typecast(uint8(app.RunButton.Value), 'uint8');
            b_Reset = typecast(uint8(app.Reset_Flag), 'uint8');

            dataPacket = [b_Kp, b_Ki, b_Kd, b_TrgX, b_TrgY, b_TrgR, b_Mode, b_StSt b_Reset];
            
            if ~isempty(app.uPortTx)
                cfg = config(); % UDP host/ports: config.m
                write(app.uPortTx, dataPacket, "uint8", cfg.udp_host, cfg.udp_send_port);
            else
                disp('UDP Tx Portu Kapalı.');
            end
        end
        
        % --- DONANIMSAL KESME (INTERRUPT / CALLBACK) ---
        function udpRxCallback(app)
            try
                % Alıcı (Receiver) portundan veriyi oku
                receivedData = read(app.uPortRx, 9, "uint8");
                
                % MATLAB'ın veriyi double yapma ihtimaline karşı zorla uint8'e çeviriyoruz!
                curr_theta = typecast(uint8(receivedData(1:4)), 'single');
                curr_omega = typecast(uint8(receivedData(5:8)), 'single');

                % Verileri arayüzün okuyacağı değişkenlere yaz
                app.Current_Theta = double(curr_theta(1)); 
                app.Current_Omega = double(curr_omega(1));
                app.Start_Stop = receivedData(9);
            catch
                % Çok nadir bir anormallik olursa sistemi çökertme, pas geç.
            end
        end
    end  

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Visualizer'ı Başlat
            app.VisObj = FourBar_Visualizer_handle(app.UIAxes, app.UIFigure);
            app.StartTime = tic;

            app.StartStopLamp.Color = [0.5 0.5 0.5]; % Gri (Veri gelene kadar belirsiz)
            
            % Feedback çizgisi (Mavi)
            app.FbLine = plot(app.UIAxes_2, NaN, NaN, 'b-', 'LineWidth', 1.5);
            hold(app.UIAxes_2, 'on');
            % Referans çizgisi (Kırmızı Kesikli)
            app.RefLine = plot(app.UIAxes_2, NaN, NaN, 'r--', 'LineWidth', 1.2);
            hold(app.UIAxes_2, 'off');
            
            % KRİTİK DÜZELTME: Başlangıçta lejantı sadece gerçek açıyı gösterecek şekilde set et
            legend(app.UIAxes_2, app.FbLine, 'Gerçek Açı', 'Location', 'northwest');
            
            % Referans çizgisini başlangıçta gizle
            app.RefLine.Visible = 'off';
            % ------------------------------------------------
            

            try
                % 1. ALICI PORTU (Sadece 5005'ten dinler, Kesme modunda çalışır)
                cfg = config(); % UDP host/ports: config.m
                app.uPortRx = udpport("LocalPort", cfg.udp_receive_port); 
                configureCallback(app.uPortRx, "byte", 9, @(~,~) app.udpRxCallback());
                
                % 2. GÖNDERİCİ PORT (Rastgele porttan çıkar, Simulink'e 5004'e gönderir)
                app.uPortTx = udpport();
                
                disp('Çift Şeritli Haberleşme (Full-Duplex) başarıyla kuruldu.');
            catch ME
                disp('UDP AÇILAMADI! Hata:'); disp(ME.message);
            end
            
            app.UpdateTimer = timer('ExecutionMode', 'fixedRate', ...
                                    'Period', 0.05, ...
                                    'BusyMode','drop', ...
                                    'TimerFcn', @(~,~) app.animationLoop());
            start(app.UpdateTimer);
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            % Timer'ı durdur ve sil
            if ~isempty(app.UpdateTimer) && isvalid(app.UpdateTimer)
                stop(app.UpdateTimer);
                delete(app.UpdateTimer);
            end
            
            % Alıcıyı Kapat (Önce kesmeyi durdur, sonra sil)
            if ~isempty(app.uPortRx)
                configureCallback(app.uPortRx, "off"); 
                delete(app.uPortRx);
                app.uPortRx = [];
            end
            
            % Vericiyi Kapat
            if ~isempty(app.uPortTx)
                delete(app.uPortTx);
                app.uPortTx = [];
            end
            
            delete(app);
        end

        % Value changed function: RunButton
        function RunButtonValueChanged(app, event)
            if ~isvalid(app)  
                return;
            end
            app.sendDataPacket(); % Basıldığı an gönder
        end

        % Selection change function: TabGroup
        function TabGroupSelectionChanged(app, event)
            if app.TabGroup.SelectedTab == app.PosControlTab
                app.Control_Mode = 0; % Pozisyon Modu
                title(app.UIAxes_2, 'Pozisyon Takibi');
                ylabel(app.UIAxes_2, 'Açı [deg]');
                
                % --- LEJANT VE ÇİZGİ GÜNCELLEMESİ (POZİSYON) ---
                % Sadece Feedback çizgisini isimlendir
                legend(app.UIAxes_2, app.FbLine, 'Gerçek Açı', 'Location', 'northwest');
                % Referans çizgisini gizle (çünkü hedef Simulink'te hesaplanıyor)
                app.RefLine.Visible = 'off';
                
            elseif app.TabGroup.SelectedTab == app.SpdControlTab
                app.Control_Mode = 1; % Hız Modu
                title(app.UIAxes_2, 'Hız Takibi');
                ylabel(app.UIAxes_2, 'Hız [rpm]');
                
                % --- LEJANT VE ÇİZGİ GÜNCELLEMESİ (HIZ) ---
                % Her iki çizgiyi de isimlendir
                legend(app.UIAxes_2, [app.FbLine, app.RefLine], {'Gerçek Hız', 'Hedef Hız'}, 'Location', 'northwest');
                % Referans çizgisini tekrar görünür yap
                app.RefLine.Visible = 'on';
            end
            
            % Grafiği ve Kronometreyi Sıfırla
            app.TimeData = [];
            app.PlotFbData = [];
            app.PlotRefData = [];
            app.StartTime = tic;
        end

        % Button pushed function: ResetButton
        function ResetButtonPushed(app, event)
            app.Reset_Flag = ~app.Reset_Flag;
            app.sendDataPacket();
        end

        % Button pushed function: ResetButton_2
        function ResetButton_2Pushed(app, event)
            app.Reset_Flag = ~app.Reset_Flag;
            app.sendDataPacket();
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1306 580];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Title')
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [441 1 865 578];

            % Create UIAxes_2
            app.UIAxes_2 = uiaxes(app.UIFigure);
            title(app.UIAxes_2, 'Pos/Spd')
            xlabel(app.UIAxes_2, 'Time')
            ylabel(app.UIAxes_2, 'Y')
            zlabel(app.UIAxes_2, 'Z')
            app.UIAxes_2.Position = [6 1 436 172];

            % Create StartStopLampLabel
            app.StartStopLampLabel = uilabel(app.UIFigure);
            app.StartStopLampLabel.HorizontalAlignment = 'right';
            app.StartStopLampLabel.Position = [312 539 58 22];
            app.StartStopLampLabel.Text = 'Start/Stop';

            % Create StartStopLamp
            app.StartStopLamp = uilamp(app.UIFigure);
            app.StartStopLamp.Position = [321 499 41 41];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);
            app.TabGroup.Position = [14 179 417 288];

            % Create PosControlTab
            app.PosControlTab = uitab(app.TabGroup);
            app.PosControlTab.Title = 'Pos Control';

            % Create KdEditFieldLabel
            app.KdEditFieldLabel = uilabel(app.PosControlTab);
            app.KdEditFieldLabel.HorizontalAlignment = 'right';
            app.KdEditFieldLabel.Position = [21 134 25 22];
            app.KdEditFieldLabel.Text = 'Kd';

            % Create KdEditField
            app.KdEditField = uieditfield(app.PosControlTab, 'numeric');
            app.KdEditField.Position = [61 134 100 22];
            app.KdEditField.Value = 3.08;

            % Create KiEditFieldLabel
            app.KiEditFieldLabel = uilabel(app.PosControlTab);
            app.KiEditFieldLabel.HorizontalAlignment = 'right';
            app.KiEditFieldLabel.Position = [21 174 25 22];
            app.KiEditFieldLabel.Text = 'Ki';

            % Create KiEditField
            app.KiEditField = uieditfield(app.PosControlTab, 'numeric');
            app.KiEditField.Position = [61 174 100 22];
            app.KiEditField.Value = 296;

            % Create KpEditFieldLabel
            app.KpEditFieldLabel = uilabel(app.PosControlTab);
            app.KpEditFieldLabel.HorizontalAlignment = 'right';
            app.KpEditFieldLabel.Position = [21 214 25 22];
            app.KpEditFieldLabel.Text = 'Kp';

            % Create KpEditField
            app.KpEditField = uieditfield(app.PosControlTab, 'numeric');
            app.KpEditField.Position = [61 214 100 22];
            app.KpEditField.Value = 118.36;

            % Create XEditFieldLabel
            app.XEditFieldLabel = uilabel(app.PosControlTab);
            app.XEditFieldLabel.HorizontalAlignment = 'right';
            app.XEditFieldLabel.Position = [216 214 25 22];
            app.XEditFieldLabel.Text = 'X';

            % Create XEditField
            app.XEditField = uieditfield(app.PosControlTab, 'numeric');
            app.XEditField.Editable = 'off';
            app.XEditField.Position = [256 214 100 22];

            % Create YEditFieldLabel
            app.YEditFieldLabel = uilabel(app.PosControlTab);
            app.YEditFieldLabel.HorizontalAlignment = 'right';
            app.YEditFieldLabel.Position = [216 175 25 22];
            app.YEditFieldLabel.Text = 'Y';

            % Create YEditField
            app.YEditField = uieditfield(app.PosControlTab, 'numeric');
            app.YEditField.Editable = 'off';
            app.YEditField.Position = [256 175 100 22];

            % Create PosEditFieldLabel
            app.PosEditFieldLabel = uilabel(app.PosControlTab);
            app.PosEditFieldLabel.HorizontalAlignment = 'right';
            app.PosEditFieldLabel.Position = [215 133 26 22];
            app.PosEditFieldLabel.Text = 'Pos';

            % Create PosEditField
            app.PosEditField = uieditfield(app.PosControlTab, 'numeric');
            app.PosEditField.Editable = 'off';
            app.PosEditField.Position = [256 132.5 100 22];

            % Create ResetButton
            app.ResetButton = uibutton(app.PosControlTab, 'push');
            app.ResetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetButtonPushed, true);
            app.ResetButton.Position = [61 50 100 22];
            app.ResetButton.Text = 'Reset';

            % Create SpdControlTab
            app.SpdControlTab = uitab(app.TabGroup);
            app.SpdControlTab.Title = 'Spd Control';

            % Create SpeedsetEditFieldLabel
            app.SpeedsetEditFieldLabel = uilabel(app.SpdControlTab);
            app.SpeedsetEditFieldLabel.HorizontalAlignment = 'right';
            app.SpeedsetEditFieldLabel.Position = [182 214 59 22];
            app.SpeedsetEditFieldLabel.Text = 'Speed set';

            % Create SpeedsetEditField
            app.SpeedsetEditField = uieditfield(app.SpdControlTab, 'numeric');
            app.SpeedsetEditField.Position = [256 214 100 22];
            app.SpeedsetEditField.Value = 10;

            % Create KdEditField_2Label
            app.KdEditField_2Label = uilabel(app.SpdControlTab);
            app.KdEditField_2Label.HorizontalAlignment = 'right';
            app.KdEditField_2Label.Position = [21 134 25 22];
            app.KdEditField_2Label.Text = 'Kd';

            % Create KdEditField_2
            app.KdEditField_2 = uieditfield(app.SpdControlTab, 'numeric');
            app.KdEditField_2.Position = [61 134 100 22];
            app.KdEditField_2.Value = 0.005;

            % Create KpEditField_3Label
            app.KpEditField_3Label = uilabel(app.SpdControlTab);
            app.KpEditField_3Label.HorizontalAlignment = 'right';
            app.KpEditField_3Label.Position = [21 214 25 22];
            app.KpEditField_3Label.Text = 'Kp';

            % Create KpEditField_3
            app.KpEditField_3 = uieditfield(app.SpdControlTab, 'numeric');
            app.KpEditField_3.Position = [61 214 100 22];
            app.KpEditField_3.Value = 10;

            % Create KiEditField_2Label
            app.KiEditField_2Label = uilabel(app.SpdControlTab);
            app.KiEditField_2Label.HorizontalAlignment = 'right';
            app.KiEditField_2Label.Position = [21 174 25 22];
            app.KiEditField_2Label.Text = 'Ki';

            % Create KiEditField_2
            app.KiEditField_2 = uieditfield(app.SpdControlTab, 'numeric');
            app.KiEditField_2.Position = [61 174 100 22];
            app.KiEditField_2.Value = 113;

            % Create SpdrpmRPMIndicatorLabel
            app.SpdrpmRPMIndicatorLabel = uilabel(app.SpdControlTab);
            app.SpdrpmRPMIndicatorLabel.HorizontalAlignment = 'center';
            app.SpdrpmRPMIndicatorLabel.Position = [277 11 57 22];
            app.SpdrpmRPMIndicatorLabel.Text = 'Spd [rpm]';

            % Create SpdrpmRPMIndicator
            app.SpdrpmRPMIndicator = uiaerorpm(app.SpdControlTab);
            app.SpdrpmRPMIndicator.Position = [245 32 121 121];

            % Create SpeedfbEditFieldLabel
            app.SpeedfbEditFieldLabel = uilabel(app.SpdControlTab);
            app.SpeedfbEditFieldLabel.HorizontalAlignment = 'right';
            app.SpeedfbEditFieldLabel.Position = [188 175 53 22];
            app.SpeedfbEditFieldLabel.Text = 'Speed fb';

            % Create SpeedfbEditField
            app.SpeedfbEditField = uieditfield(app.SpdControlTab, 'numeric');
            app.SpeedfbEditField.Editable = 'off';
            app.SpeedfbEditField.Position = [256 174.714285714286 100 22];

            % Create ResetButton_2
            app.ResetButton_2 = uibutton(app.SpdControlTab, 'push');
            app.ResetButton_2.ButtonPushedFcn = createCallbackFcn(app, @ResetButton_2Pushed, true);
            app.ResetButton_2.Position = [61 50 100 22];
            app.ResetButton_2.Text = 'Reset';

            % Create RunButton
            app.RunButton = uibutton(app.UIFigure, 'state');
            app.RunButton.ValueChangedFcn = createCallbackFcn(app, @RunButtonValueChanged, true);
            app.RunButton.Text = 'Run';
            app.RunButton.FontWeight = 'bold';
            app.RunButton.Position = [85 508 80 32];

            % Create ErrorLampLabel
            app.ErrorLampLabel = uilabel(app.UIFigure);
            app.ErrorLampLabel.HorizontalAlignment = 'right';
            app.ErrorLampLabel.Position = [210 513 32 22];
            app.ErrorLampLabel.Text = 'Error';

            % Create ErrorLamp
            app.ErrorLamp = uilamp(app.UIFigure);
            app.ErrorLamp.Position = [257 513 20 20];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = UI_UDP_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end