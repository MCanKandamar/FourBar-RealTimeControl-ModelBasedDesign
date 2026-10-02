classdef ControlMode < Simulink.IntEnumType
    %CONTROLMODE Control mode selected in the MATLAB app.
    %   The values match the mode byte sent by UI_Serial / UI_UDP
    %   (0 = position control, 1 = speed control).
    enumeration
        PositionControl(0)
        SpeedControl(1)
    end
end
