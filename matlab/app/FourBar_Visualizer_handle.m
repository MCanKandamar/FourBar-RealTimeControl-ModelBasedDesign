classdef FourBar_Visualizer_handle < handle
    % FOURBAR_VISUALIZER (App Designer Uyumlu Versiyon)
    
    properties (Access = public)
        target_XY = [0, 0]; % Dışarı verilecek X ve Y koordinatları
        target_theta2 = 0;  % EKLENDİ: Tıklanan hedefin motor açısı

        % EKLENEN: Gerçek zamanlı uç nokta koordinatları
        current_PX = 0; 
        current_PY = 0;
    end
    
    properties (Access = private)
        fig_handle % App'in UIFigure objesi
        ax_handle  % App'in UIAxes objesi
        
        h_crank, h_rocker, h_coupler, h_pointP
        h_targetPoint % Hedefi gösterecek işaretçi (Target Marker)
        theta2_arr, Px_arr, Py_arr
        
        a = 70; b = 190; c = 150; d = 240;
        alpha_rad = 40 * (pi / 180);
        L_ap
        isDragging = false;
        current_theta2_actual = 0;
    end
    
    methods
        % Constructor (Kurucu Fonksiyon)
        function obj = FourBar_Visualizer_handle(app_axes, app_fig)
            obj.ax_handle = app_axes;
            obj.fig_handle = app_fig;
            obj.setupGraphics();
        end
        
        function setupGraphics(obj)
            obj.L_ap = obj.b * cos(obj.alpha_rad);
            obj.theta2_arr = linspace(0, 2*pi, 360);
            num_pts = length(obj.theta2_arr);
            obj.Px_arr = zeros(1, num_pts);
            obj.Py_arr = zeros(1, num_pts);
            
            m = 1; % Çapraz Mod (Crossed Mode)
            
            for i = 1:num_pts
                th2 = obj.theta2_arr(i);
                A_eq = 2 * obj.c * (obj.d - obj.a * cos(th2));
                B_eq = -2 * obj.a * obj.c * sin(th2);
                C_eq = obj.a^2 - obj.b^2 + obj.c^2 + obj.d^2 - 2 * obj.a * obj.d * cos(th2);
                
                disc4 = max(0, B_eq^2 - C_eq^2 + A_eq^2);
                th4 = 2 * atan2(-B_eq - m * sqrt(disc4), C_eq - A_eq);
                
                Ax = obj.a * cos(th2); Ay = obj.a * sin(th2);
                Bx = obj.d + obj.c * cos(th4); By = obj.c * sin(th4);
                
                th3_actual = atan2(By - Ay, Bx - Ax);
                obj.Px_arr(i) = Ax + obj.L_ap * cos(th3_actual + obj.alpha_rad);
                obj.Py_arr(i) = Ay + obj.L_ap * sin(th3_actual + obj.alpha_rad);
            end
            
            obj.target_XY = [obj.Px_arr(1), obj.Py_arr(1)];
            
            % Eksen ayarları
            hold(obj.ax_handle, 'on'); 
            axis(obj.ax_handle, 'equal'); 
            grid(obj.ax_handle, 'on');
            xlim(obj.ax_handle, [-150, 400]); ylim(obj.ax_handle, [-150, 250]);
            
            plot(obj.ax_handle, obj.Px_arr, obj.Py_arr, 'w:', 'LineWidth', 1);
            plot(obj.ax_handle, [0, obj.d], [0, 0], 'ko', 'MarkerFaceColor', 'c');
            
            obj.h_crank = plot(obj.ax_handle, [0,0], [0,0], 'r-', 'LineWidth', 1);
            obj.h_rocker = plot(obj.ax_handle, [0,0], [0,0], 'b-', 'LineWidth', 1);
            obj.h_coupler = patch(obj.ax_handle, [0,0,0], [0,0,0], 'g', 'FaceAlpha', 0.4, 'EdgeColor', 'none');
            obj.h_pointP = plot(obj.ax_handle, 0, 0, 'mo', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
            
            % --- EKLENDİ: Hedef noktası için siyah büyük bir çarpı (X) ---
            obj.h_targetPoint = plot(obj.ax_handle, obj.target_XY(1), obj.target_XY(2), ...
                                     'cx', 'MarkerSize', 12, 'LineWidth', 1);
            % --------

            % Fare Olayları
            obj.fig_handle.WindowButtonDownFcn = @obj.onMouseDown;
            obj.fig_handle.WindowButtonMotionFcn = @obj.onMouseMove;
            obj.fig_handle.WindowButtonUpFcn = @obj.onMouseUp;
        end
        
        function updateAnimation(obj, theta2_current)
            obj.current_theta2_actual = theta2_current;
            m = 1;
            
            % Kinematik hesaplamalar
            A_eq = 2 * obj.c .* (obj.d - obj.a .* cos(theta2_current));
            B_eq = -2 * obj.a .* obj.c .* sin(theta2_current);
            C_eq = obj.a.^2 - obj.b.^2 + obj.c.^2 + obj.d^2 - 2 * obj.a * obj.d .* cos(theta2_current);
            
            disc4 = max(0, B_eq.^2 - C_eq.^2 + A_eq.^2);
            th4 = 2 * atan2(-B_eq - m * sqrt(disc4), C_eq - A_eq);
            
            Ax = obj.a * cos(theta2_current); Ay = obj.a * sin(theta2_current);
            Bx = obj.d + obj.c * cos(th4); By = obj.c * sin(th4);
            
            th3_actual = atan2(By - Ay, Bx - Ax);
            
            % Uç nokta (Point P) koordinatlarını hesapla
            Px = Ax + obj.L_ap * cos(th3_actual + obj.alpha_rad);
            Py = Ay + obj.L_ap * sin(th3_actual + obj.alpha_rad);
            
            % EKLENEN: Hesaplanan koordinatları public property'lere ata
            obj.current_PX = Px;
            obj.current_PY = Py;
            
            % Grafikleri güncelle
            if isvalid(obj.ax_handle)
                set(obj.h_crank, 'XData', [0, Ax], 'YData', [0, Ay]);
                set(obj.h_rocker, 'XData', [obj.d, Bx], 'YData', [0, By]);
                set(obj.h_coupler, 'XData', [Ax, Bx, Px], 'YData', [Ay, By, Py]);
                set(obj.h_pointP, 'XData', Px, 'YData', Py);
            end
        end
    end
    
    methods (Access = private)
        % Fare tıklanınca (Mouse Down)
        function onMouseDown(obj, ~, ~)
            if isvalid(obj.ax_handle)
                % Farenin anlık koordinatını al
                click_pt = get(obj.ax_handle, 'CurrentPoint');
                x_click = click_pt(1, 1); 
                y_click = click_pt(1, 2);
                
                % Eksenlerin (Axes) sınırlarını al
                xl = xlim(obj.ax_handle);
                yl = ylim(obj.ax_handle);
                
                % KRİTİK FİLTRE: Sadece grafik sınırları içine tıklandıysa kabul et!
                if x_click >= xl(1) && x_click <= xl(2) && y_click >= yl(1) && y_click <= yl(2)
                    obj.isDragging = true;
                    obj.updateTargetFromMouse();
                end
            end
        end
        
        % Fare sürüklenirken (Mouse Move)
        function onMouseMove(obj, ~, ~)
            if obj.isDragging && isvalid(obj.ax_handle)
                obj.updateTargetFromMouse();
            end
        end
        
        % Fare bırakılınca (Mouse Up)
        function onMouseUp(obj, ~, ~)
            obj.isDragging = false; 
        end
        
        % Hedefi Güncelle (Update Target)
        function updateTargetFromMouse(obj)
            click_pt = get(obj.ax_handle, 'CurrentPoint');
            x_click = click_pt(1, 1); y_click = click_pt(1, 2);
            
            % En yakın noktayı bul (Nearest Neighbor Search)
            distances = sqrt((obj.Px_arr - x_click).^2 + (obj.Py_arr - y_click).^2);
            [~, idx] = min(distances);
            
            obj.target_XY = [obj.Px_arr(idx), obj.Py_arr(idx)];
            obj.target_theta2 = obj.theta2_arr(idx); 
            
            % --- EKLENDİ: Hedef işaretçisini (X) yeni yerine taşı ---
            if isvalid(obj.h_targetPoint)
                set(obj.h_targetPoint, 'XData', obj.target_XY(1), 'YData', obj.target_XY(2));
            end
            % -----------------------------------------------------
        end
    end
end