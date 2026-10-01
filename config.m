function cfg = config()
%CONFIG Central communication settings for the MATLAB apps.
%   cfg = config() returns a struct read by matlab/app/UI_Serial_exported.m
%   and matlab/app/UI_UDP_exported.m. Edit the values below to match your PC.
%
%   Note: the App Designer sources (UI_Serial.mlapp, UI_UDP.mlapp) still hold
%   their own hardcoded values until they are updated in App Designer.

% --- Serial (UART) link to the Arduino: hardware mode, UI_Serial ---
cfg.serial_port = "COM9";   % Windows: "COMx" | Linux: "/dev/ttyACM0" | macOS: "/dev/cu.usbmodemXXXX"
cfg.baud_rate   = 9600;     % must match the Serial0 baud rate set in simulink/realtime_controller.slx

% --- UDP link to the desktop simulation: simulation mode, UI_UDP ---
cfg.udp_host         = "127.0.0.1";
cfg.udp_send_port    = 5004;   % app -> Simulink (UDP Receive block, local port)
cfg.udp_receive_port = 5005;   % Simulink -> app (UDP Send block, remote port)
end
