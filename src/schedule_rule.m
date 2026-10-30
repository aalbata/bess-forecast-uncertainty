function [Pch, Pdis] = schedule_rule(D, P)
%SCHEDULE_RULE Rule-based battery schedule (controller B1).
%   Charges at 120 kW before 06:00 until the state of charge reaches 0.72, discharges between
%   17:00 and 21:00 whenever net load exceeds 780 kW, and restores the initial state of charge
%   after 22:00. Power and state-of-charge limits are enforced at every interval.

target = 780;
reserve = 0.72;
s = P.s0;
pb = zeros(P.N, 1);
for k = 1:P.N
    h = D.t(k);
    p = 0;
    if h < 6 && s < reserve
        p = -120;
    elseif h >= 17 && h < 21 && D.net(k) > target && s > P.smin
        p = min(P.Pmax, D.net(k) - target);
    elseif h >= 22
        gap = (P.s0 - s)*P.E;
        if gap > 0
            p = -min(P.Pmax, gap/(P.etaC*P.dt));
        elseif gap < 0
            p = min(P.Pmax, (-gap)*P.etaD/P.dt);
        end
    end
    if p >= 0
        p = min(p, max(0, (s - P.smin)*P.E*P.etaD/P.dt));
        s = s - (p/P.etaD)*P.dt/P.E;
    else
        pc = min(-p, max(0, (P.smax - s)*P.E/(P.etaC*P.dt)));
        p = -pc;
        s = s + (P.etaC*pc)*P.dt/P.E;
    end
    pb(k) = p;
end
Pch = max(-pb, 0);
Pdis = max(pb, 0);
end
