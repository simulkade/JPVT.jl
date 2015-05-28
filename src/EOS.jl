function PREOS(mixture, thermo)

mixing_rule_num = thermo.mixingrule;
activityfun = thermo.activity_model;
phase1 = thermo.phase;
fug_need = thermo.fugacity_switch;
critical_pres = [mixture.components.Pc]; %[Pa]
critical_temp = [mixture.components.Tc]; %[K]
acentric_fact = [mixture.components.acentric_factor]; %[-]
BIP = mixture.bip;
x = mixture.mole_fraction;
p = mixture.pressure; %[Pa]
T = mixture.temperature;
N = length(critical_temp);
fugacity = zeros(1,N);
R=8.314;
s1 = 0.623225;  %Huron Vidal

bi = 0.077796*R*critical_temp./critical_pres;
aci=0.457235*(R*critical_temp).^2 ./critical_pres;
mi = 0.37646+(1.54226-0.26992*acentric_fact).*acentric_fact;
Tr = T./critical_temp;
alfai = 1+mi.*(1-sqrt(Tr));   %//alfai=ai^0.5
alfa = alfai.^2.0;           %//alfa=ai
ai = aci .* alfa;
%Q is the parameter for MHV1 and MHV2 mixing rule
%it depends on the EOS
Q = (mixing_rule_num==3)*[-0.53 0]+(mixing_rule_num==4)*[-0.4347 -0.003654];
[a, b] = mixing_rule(mixture, thermo, ai, bi, s1, Q);

A_coef=a*p/(R*T)^2;
B_coef=b*p/(R*T);
%        poly_coef(4)=-B_coef*(A_coef-B_coef*(1+B_coef));
%        poly_coef(3)=A_coef-B_coef*(2.0+3*B_coef);
%        poly_coef(2)=-1+B_coef;
%        poly_coef(1)=1;
poly_coef = [1 -1+B_coef A_coef-B_coef*(2.0+3*B_coef) ...
    -B_coef*(A_coef-B_coef*(1+B_coef))];


z_root = roots(poly_coef);
if (sum(imag(z_root)~=0)==0)
    liquid_z = min(z_root);
    vapor_z = max(z_root);
else
    liquid_z = z_root(imag(z_root)==0);
    vapor_z = liquid_z;
end
% %{now we should calculate vapor and liquid
% %compressibility factor by the following method :}
% real_part = real(z_root);
% imag_part = imag(z_root);
% % findmaxmin(real_part,img_part,zv,zl);
% max_no=real_part(3);
% min_no=real_part(3);
% for i=1:3
%    if ((real_part(i)>max_no) && (real_part(i)>0) && (imag_part(i)==0))
%        max_no=real_part(i);
%    end
%    if ((real_part(i)<min_no) && (real_part(i)>0) && (imag_part(i)==0))
%          min_no=real_part(i);
%    end
% end
%      liquid_z = min_no;
%      vapor_z = max_no;
if (phase1==1)     %then  //phase 1 is liquid
   zz=liquid_z;
elseif (phase1==2) %then    //phase 2 is vapor
   zz=vapor_z;
end

if (fug_need==1)
    if (mixing_rule_num==1) %simple mixing rule
        part1=bi/b*(zz-1)-log(zz-b*p/(R*T));
        part2=x*(sqrt(ai'*ai).*(1-[BIP.EOScons]-[BIP.EOStdep]*T))';
        part3=A_coef/(2.828*B_coef)*(bi/b-2/a*part2) ...
            *log((zz+2.414*b*p/(R*T))/(zz-0.414*b*p/(R*T)));
        fugacity=exp(part1+part3);
    elseif (mixing_rule_num==2)  %Huron Vidal mixing rule
        [~, gama] = activityfun(T, x, component, BIP);
        part1 = bi/b*(zz-1)-log(zz-b*p/(R*T));
        part3 = -1/(2*sqrt(2))*(ai./bi/R/T - ...
                   log(gama)/0.623225)* ...
                   log((zz+(1+sqrt(2))*B_coef)/(zz+(1-sqrt(2))*B_coef));
        fugacity = exp(part1+part3);
    elseif (mixing_rule_num==3) % MHV1 mixing rule
        [~, gama] = activityfun(T, x, component, BIP);
        q1 = -0.53;  %Michelsen for PR
        logfi = bi/b*(zz-1) - log(zz-B_coef) - 1/(2*sqrt(2))*(ai./(bi*R*T) ...
            + log(gama)/q1+log(b./bi)/q1+(bi/b-1)/q1)*log((zz+(1+sqrt(2))*B_coef)/ ...
            (zz+(1-sqrt(2))*B_coef));
        fugacity = exp(logfi);
    elseif (mixing_rule_num==4) % MHV2 mixing rule
        [~, gama] = activityfun(T, x, component, BIP);
        q1 = -0.4347;
        q2 = -0.003654;
        alphai = ai./(bi*R*T);
        alpha = a/(b*R*T);
        logfi = bi/b*(zz-1) - log(zz-B_coef) - ...
            1/(2*sqrt(2))*(q1*alphai+q2*(alpha^2+alphai.^2)+log(gama) ...
            +log(b./bi)+bi/b-1)/(q1+2*q2*alpha)* ...
            log((zz+(1+sqrt(2))*B_coef)/(zz+(1-sqrt(2))*B_coef));
        fugacity = exp(logfi);
    end
end

%% calculate the residual enthalpy
for i=1:N
   Abar(i)=0;
   for j=1:N
     Abar(i)=Abar(i)+sqrt(ai(j))/(R*T)*x(j);
   end
   Abar(i)=Abar(i)*sqrt(ai(i))/(R*T);
end
 part1=0;
 for i=1:N
   part1=part1+x(i)*Abar(i)*mi(i)*(-1)/sqrt(critical_temp(i))/alfai(i);
 end
 part1=(part1*T^0.5/(A_coef/p)-1)*R*T*A_coef/(B_coef*2*sqrt(2))*log((zz+B_coef*(1+sqrt(2)))/(zz+B_coef*(1-sqrt(2))));
 HR=part1+R*T*(zz-1);
% HR=0;
