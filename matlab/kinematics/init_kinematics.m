% init_kinematics.m (Simülasyon başlamadan önce bir kez çalıştırılır)
a = 70; b = 190; c = 150; d = 240;
alpha_rad = 40 * (pi/180);
L_ap = b * cos(alpha_rad);
m = 1; % Çapraz Mod
sample = 100;
theta2_LUT = linspace(0, 2*pi, sample);
Px_LUT = zeros(1, sample);
Py_LUT = zeros(1, sample);

for i = 1:sample
    th2 = theta2_LUT(i);
    A_eq = 2 * c * (d - a * cos(th2));
    B_eq = -2 * a * c * sin(th2);
    C_eq = a^2 - b^2 + c^2 + d^2 - 2 * a * d * cos(th2);
    
    disc4 = max(0, B_eq^2 - C_eq^2 + A_eq^2);
    th4 = 2 * atan2(-B_eq - m * sqrt(disc4), C_eq - A_eq);
    
    Ax = a * cos(th2); Ay = a * sin(th2);
    Bx = d + c * cos(th4); By = c * sin(th4);
    
    th3_actual = atan2(By - Ay, Bx - Ax);
    Px_LUT(i) = Ax + L_ap * cos(th3_actual + alpha_rad);
    Py_LUT(i) = Ay + L_ap * sin(th3_actual + alpha_rad);
end
Px_LUT = single(Px_LUT);
Py_LUT = single(Py_LUT);
theta2_LUT = single(theta2_LUT);
disp('Arama Tabloları (Look-Up Tables) Workspace''e yüklendi.');
clearvars -except Px_LUT Py_LUT theta2_LUT