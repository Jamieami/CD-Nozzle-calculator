function MultiFluid_Nozzle_Simulator
% MULTIFLUID NOZZLE SIMULATOR - standalone MATLAB UI (R2021a+)
% Gas: quasi-1D calorically perfect isentropic design branch (choked).
% Liquid: steady incompressible Bernoulli + continuity, optional lumped loss.
% Animations are 1D property maps and illustrative tracers, NOT CFD.
% Run: MultiFluid_Nozzle_Simulator

C.bg=[.055 .080 .125]; C.panel=[.09 .13 .19]; C.card=[.13 .19 .27];
C.fg=[.94 .97 1]; C.muted=[.68 .77 .85]; C.blue=[.20 .69 .95];
C.warn=[1 .73 .34]; C.good=[.35 .86 .63];
psi=6894.757293;
fluids={'Air','Nitrogen','Helium','Hydrogen','Oxygen','Carbon dioxide', ...
    'Water','Ethanol','Glycerol','Custom gas','Custom liquid'};
fig=uifigure('Name','MULTIFLUID | Nozzle Flow Laboratory','Position',[45 45 1530 900], ...
    'Color',C.bg);
fig.AutoResizeChildren='off';
root=uigridlayout(fig,[1 2],'ColumnWidth',{365,'1x'},'RowHeight',{'1x'}, ...
    'Padding',[12 12 12 12],'ColumnSpacing',12,'BackgroundColor',C.bg);
left=uipanel(root,'BackgroundColor',C.panel,'BorderType','none');
left.Layout.Column=1;
lg=uigridlayout(left,[21 2],'ColumnWidth',{'1x',135}, ...
    'RowHeight',{31,28,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,40,36,'1x',24}, ...
    'Padding',[12 10 12 10],'RowSpacing',5,'ColumnSpacing',7,'BackgroundColor',C.panel);
label(lg,'FLUID & NOZZLE INPUTS',1,1,2,18,C.fg,true);
label(lg,'Choose fluid; customize properties if needed',2,1,2,10,C.muted,false);
label(lg,'Fluid',3,1,1,11,C.fg,false);
fluidDrop=uidropdown(lg,'Items',fluids,'Value','Air','ValueChangedFcn',@fluidChanged);
fluidDrop.Layout.Row=3;fluidDrop.Layout.Column=2;
fields=struct();fieldLabels=struct();
rows={ ...
 'gamma','Heat ratio gamma',1.4; ...
 'R','Gas constant R [J/kg/K]',287.05; ...
 'rho','Liquid density [kg/m^3]',998.2; ...
 'mu','Viscosity [Pa s]',0.001002; ...
 'P0','Gas stagnation / liquid inlet P [psia]',100; ...
 'T0','Inlet temperature [K]',300; ...
 'Pa','Back / outlet pressure [psia]',14.5; ...
 'Me','Gas target exit Mach',1.5; ...
 'Dt','Throat diameter [mm]',10; ...
 'Din','Inlet diameter [mm]',20; ...
 'alpha','Converging half-angle [deg]',20; ...
 'beta','Diverging half-angle [deg]',10; ...
 'K','Liquid total loss coefficient K',0; ...
 'Pv','Liquid vapor pressure [kPa abs]',3.17};
for i=1:size(rows,1)
    rr=i+3;
    fieldLabels.(rows{i,1})=label(lg,rows{i,2},rr,1,1,10,C.fg,false);
    f=uieditfield(lg,'numeric','Value',rows{i,3},'BackgroundColor',C.card, ...
        'FontColor',C.fg,'HorizontalAlignment','right','FontSize',11);
    f.Layout.Row=rr;f.Layout.Column=2;fields.(rows{i,1})=f;
end
calcBtn=uibutton(lg,'push','Text','CALCULATE / UPDATE FLOW', ...
    'BackgroundColor',[.10 .47 .76],'FontColor',C.fg,'FontWeight','bold', ...
    'ButtonPushedFcn',@calculate);calcBtn.Layout.Row=18;calcBtn.Layout.Column=[1 2];
exportBtn=uibutton(lg,'push','Text','EXPORT DATA + CAD CSV', ...
    'BackgroundColor',C.card,'FontColor',C.fg,'FontWeight','bold', ...
    'ButtonPushedFcn',@exportData);exportBtn.Layout.Row=19;exportBtn.Layout.Column=[1 2];
label(lg,'Gas = ideal compressible | Liquid = incompressible',21,1,2,10,C.muted,false);

right=uipanel(root,'BackgroundColor',C.bg,'BorderType','none');right.Layout.Column=2;
rg=uigridlayout(right,[4 1],'RowHeight',{45,96,84,'1x'}, ...
    'Padding',[0 0 0 0],'RowSpacing',8,'BackgroundColor',C.bg);
label(rg,'MULTIFLUID  /  INTERACTIVE NOZZLE LAB',1,1,1,21,C.fg,true);
mg=uigridlayout(rg,[1 4],'ColumnWidth',{'1x','1x','1x','1x'}, ...
    'Padding',[0 0 0 0],'ColumnSpacing',8,'BackgroundColor',C.bg);mg.Layout.Row=2;
metricNames={'EXIT SPEED','MASS FLOW','EXIT PRESSURE','IDEAL FORCE'};
metrics=cell(1,4);
for j=1:4
    p=uipanel(mg,'BackgroundColor',C.panel,'BorderType','none');p.Layout.Column=j;
    g=uigridlayout(p,[2 1],'RowHeight',{23,'1x'},'Padding',[11 7 11 7], ...
        'BackgroundColor',C.panel);
    label(g,metricNames{j},1,1,1,10,C.muted,true);
    metrics{j}=label(g,'--',2,1,1,20,C.fg,true);
end
statusPanel=uipanel(rg,'BackgroundColor',C.panel,'BorderType','none');statusPanel.Layout.Row=3;
sg=uigridlayout(statusPanel,[2 1],'RowHeight',{27,'1x'},'Padding',[12 6 12 6], ...
    'BackgroundColor',C.panel);
status=label(sg,'AWAITING CALCULATION',1,1,1,13,C.warn,true);
detail=label(sg,'',2,1,1,11,C.muted,false);detail.WordWrap='on';
tabs=uitabgroup(rg);tabs.Layout.Row=4;
tabFlow=uitab(tabs,'Title','SIX PLOTS','BackgroundColor',C.bg);
tabLive=uitab(tabs,'Title','LIVE FLOW FIELD','BackgroundColor',C.bg);
tabResults=uitab(tabs,'Title','PERFORMANCE / WARNINGS','BackgroundColor',C.bg);
pg=uigridlayout(tabFlow,[3 2],'RowHeight',{'1x','1x','1x'}, ...
    'ColumnWidth',{'1x','1x'},'Padding',[7 7 7 7], ...
    'RowSpacing',7,'ColumnSpacing',7,'BackgroundColor',C.bg);
ax=gobjects(1,6);
plotTitles={'Internal nozzle contour','Mach / speed ratio','Static pressure [psia]', ...
    'Temperature [K]','Velocity [m/s]','Density [kg/m^3]'};
for j=1:6
    ax(j)=uiaxes(pg);ax(j).Layout.Row=ceil(j/2);ax(j).Layout.Column=mod(j-1,2)+1;
    styleAxes(ax(j));title(ax(j),plotTitles{j},'Color',C.fg);
    xlabel(ax(j),'Axial position [mm]');grid(ax(j),'on');
end
ag=uigridlayout(tabLive,[4 1],'RowHeight',{43,'1x',94,33}, ...
    'Padding',[9 9 9 9],'RowSpacing',7,'BackgroundColor',C.bg);
controls=uigridlayout(ag,[1 8], ...
    'ColumnWidth',{98,72,65,120,57,72,65,'1x'}, ...
    'Padding',[0 0 0 0],'BackgroundColor',C.bg);controls.Layout.Row=1;
playBtn=uibutton(controls,'push','Text','PLAY','ButtonPushedFcn',@togglePlay, ...
    'BackgroundColor',[.10 .47 .76],'FontColor',C.fg);playBtn.Layout.Column=1;
resetBtn=uibutton(controls,'push','Text','RESET','ButtonPushedFcn',@resetParticles, ...
    'BackgroundColor',C.card,'FontColor',C.fg);resetBtn.Layout.Column=2;
label(controls,'Color:',1,3,1,11,C.muted,false);
colorDrop=uidropdown(controls,'Items',{'Velocity','Pressure','Temperature','Density','Mach'}, ...
    'Value','Velocity','ValueChangedFcn',@redrawLive);colorDrop.Layout.Column=4;
label(controls,'Speed:',1,5,1,11,C.muted,false);
speedDrop=uidropdown(controls,'Items',{'0.25x','0.5x','1x','2x','4x'}, ...
    'ItemsData',[.25 .5 1 2 4],'Value',1);speedDrop.Layout.Column=6;
label(controls,'View:',1,7,1,11,C.muted,false);
modeDrop=uidropdown(controls,'Items',{'Field + tracers','Field only','Tracers only'}, ...
    'Value','Field + tracers','ValueChangedFcn',@redrawLive);modeDrop.Layout.Column=8;
flowAx=uiaxes(ag);flowAx.Layout.Row=2;styleAxes(flowAx);
title(flowAx,'Animated quasi-1D flow map (illustrative tracers)','Color',C.fg);
xlabel(flowAx,'Axial position [mm]');ylabel(flowAx,'Radius [mm]');
probePanel=uipanel(ag,'BackgroundColor',C.panel,'BorderType','none');probePanel.Layout.Row=3;
probeGrid=uigridlayout(probePanel,[2 1],'RowHeight',{28,'1x'}, ...
    'Padding',[12 5 12 6],'BackgroundColor',C.panel);
probeText=label(probeGrid,'Probe: --',1,1,1,11,C.fg,true);
probeSlider=uislider(probeGrid,'Limits',[0 1],'Value',.5, ...
    'ValueChangedFcn',@probeChanged,'ValueChangingFcn',@probeChanged);
probeSlider.Layout.Row=2;
foot=label(ag,'Illustrative 1D field across each section; no CFD, turbulence, shocks, cavitation or phase change solved.', ...
    4,1,1,10,C.muted,false);foot.WordWrap='on';
resGrid=uigridlayout(tabResults,[1 1],'Padding',[10 10 10 10],'BackgroundColor',C.bg);
resultText=uitextarea(resGrid,'Editable','off','FontName','Courier New','FontSize',12, ...
    'BackgroundColor',C.panel,'FontColor',C.fg, ...
    'Value',{'Choose a fluid and click CALCULATE.'});

D=[]; phase=[]; radial=[]; scatterHandle=[]; fieldHandle=[]; probeLine=[];
tickTimer=timer('ExecutionMode','fixedSpacing','Period',.075,'BusyMode','drop', ...
    'TimerFcn',@tick);
fig.CloseRequestFcn=@closeApp;
fluidChanged();calculate();

    function h=label(parent,str,row,col,span,sz,color,bold)
        h=uilabel(parent,'Text',str,'FontColor',color,'FontSize',sz);
        if bold,h.FontWeight='bold';end
        h.Layout.Row=row;h.Layout.Column=col:(col+span-1);
    end
    function styleAxes(a)
        a.Color=C.panel;a.XColor=C.muted;a.YColor=C.muted;
        a.GridColor=C.muted;a.GridAlpha=.17;a.FontSize=10;
    end
    function [kind,p]=preset(name)
        kind='gas';p=[1.4 287.05 NaN NaN NaN];
        switch name
            case 'Air', p=[1.4 287.05 NaN NaN NaN];
            case 'Nitrogen',p=[1.4 296.8 NaN NaN NaN];
            case 'Helium',p=[1.667 2077.1 NaN NaN NaN];
            case 'Hydrogen',p=[1.405 4124 NaN NaN NaN];
            case 'Oxygen',p=[1.395 259.8 NaN NaN NaN];
            case 'Carbon dioxide',p=[1.289 188.9 NaN NaN NaN];
            case 'Water',kind='liquid';p=[NaN NaN 998.2 .001002 3.17];
            case 'Ethanol',kind='liquid';p=[NaN NaN 789 .0012 5.95];
            case 'Glycerol',kind='liquid';p=[NaN NaN 1260 1.49 .01];
            case 'Custom liquid',kind='liquid';p=[NaN NaN 998.2 .001002 3.17];
        end
    end
    function fluidChanged(~,~)
        [kind,p]=preset(fluidDrop.Value);
        gas=strcmp(kind,'gas');
        fields.gamma.Enable=onoff(gas);fields.R.Enable=onoff(gas);
        fields.Me.Enable='on';
        if gas
            fieldLabels.Me.Text='Gas target exit Mach';
        else
            fieldLabels.Me.Text='Liquid exit area ratio Ae/At';
        end
        fields.rho.Enable=onoff(~gas);fields.mu.Enable=onoff(~gas);
        fields.K.Enable=onoff(~gas);fields.Pv.Enable=onoff(~gas);
        if ~strcmp(fluidDrop.Value,'Custom gas') && ~strcmp(fluidDrop.Value,'Custom liquid')
            if gas
                fields.gamma.Value=p(1);fields.R.Value=p(2);
            else
                fields.rho.Value=p(3);fields.mu.Value=p(4);fields.Pv.Value=p(5);
            end
        end
        if gas
            plotTitles{2}='Mach number';
        else
            plotTitles{2}='Velocity / exit velocity';
        end
    end
    function v=onoff(b)
        if b,v='on';else,v='off';end
    end
    function calculate(~,~)
        try
            wasRunning=strcmp(tickTimer.Running,'on');
            if wasRunning,stop(tickTimer);playBtn.Text='PLAY';end
            p=struct();names=fieldnames(fields);
            for k=1:numel(names),p.(names{k})=fields.(names{k}).Value;end
            [kind,~]=preset(fluidDrop.Value);
            assert(all(isfinite([p.P0 p.T0 p.Pa p.Dt p.Din p.alpha p.beta])), ...
                'Inputs must be finite.');
            assert(p.P0>0 && p.Pa>0 && p.T0>0 && p.Dt>0 && p.Din>p.Dt, ...
                'Use positive absolute pressures/temperature and inlet diameter > throat.');
            assert(p.alpha>0 && p.alpha<90 && p.beta>0 && p.beta<90, ...
                'Half angles must be between 0 and 90 degrees.');
            if strcmp(kind,'gas')
                assert(p.gamma>1 && p.R>0 && p.Me>1, ...
                    'Gas requires gamma > 1, R > 0 and exit Mach > 1.');
            else
                assert(p.Me>=1 && isfinite(p.Me), ...
                    'Liquid exit area ratio must be >= 1.');
                assert(p.rho>0 && p.mu>=0 && p.K>=0 && p.Pv>=0, ...
                    'Liquid density > 0; viscosity, loss K and vapor pressure >= 0.');
                assert(p.P0>p.Pa, ...
                    'Liquid inlet pressure must exceed outlet pressure for forward flow.');
            end
            nCon=120;nDiv=180;Dt=p.Dt/1000;Din=p.Din/1000;
            At=pi*Dt^2/4;Ai=pi*Din^2/4;
            P0=p.P0*psi;Pa=p.Pa*psi;
            if strcmp(kind,'gas')
                gam=p.gamma;R=p.R;
                areaMach=@(m)(1./m).*((2/(gam+1)).*(1+(gam-1).*m.^2/2)).^ ...
                    ((gam+1)/(2*(gam-1)));
                Ae=At*areaMach(p.Me);De=sqrt(4*Ae/pi);
            else
                % Liquid exit area ratio is set using the shared geometry field.
                Ae=p.Me*At;De=sqrt(4*Ae/pi);
            end
            Lc=(Din-Dt)/2/tand(p.alpha);Ld=(De-Dt)/2/tand(p.beta);
            xc=linspace(-Lc,0,nCon);xd=linspace(0,Ld,nDiv);
            rc=Dt/2-xc*tand(p.alpha);rd=Dt/2+xd*tand(p.beta);
            x=[xc xd(2:end)];r=[rc rd(2:end)];A=pi*r.^2;
            if strcmp(kind,'gas')
                M=zeros(size(x));
                for k=1:numel(x)
                    ar=A(k)/At;
                    if abs(ar-1)<1e-11,M(k)=1;continue;end
                    if x(k)<0
                        lo=1e-10;hi=1;
                        for j=1:75
                            mid=(lo+hi)/2;
                            if areaMach(mid)>ar,lo=mid;else,hi=mid;end
                        end
                    else
                        lo=1;hi=max(4,p.Me+1);
                        while areaMach(hi)<ar,hi=2*hi;end
                        for j=1:75
                            mid=(lo+hi)/2;
                            if areaMach(mid)<ar,lo=mid;else,hi=mid;end
                        end
                    end
                    M(k)=(lo+hi)/2;
                end
                T=p.T0./(1+(gam-1)*M.^2/2);
                P=P0.*(1+(gam-1)*M.^2/2).^(-gam/(gam-1));
                rho=P./(R*T);V=M.*sqrt(gam*R*T);
                mdot=At*P0*sqrt(gam/(R*p.T0))* ...
                    (2/(gam+1))^((gam+1)/(2*(gam-1)));
                Pe=P(end);F=mdot*V(end)+(Pe-Pa)*Ae;
                shockExit=Pe*(1+2*gam/(gam+1)*(p.Me^2-1));
                mSub=bisectionSub(areaMach,Ae/At);
                pChoke=P0*(1+(gam-1)*mSub^2/2)^(-gam/(gam-1));
                if Pa<=Pe
                    regime='UNDEREXPANDED / SUPERSONIC DESIGN';
                    msg='Ideal choked supersonic branch; expansion occurs outside nozzle.';
                elseif Pa<=shockExit
                    regime='OVEREXPANDED / EXTERNAL SHOCKS POSSIBLE';
                    msg='Internal supersonic solution can remain valid; external shocks may occur.';
                elseif Pa<pChoke
                    regime='WARNING: INTERNAL SHOCK LIKELY';
                    msg='Displayed isentropic gas profile is DESIGN ONLY; actual shock flow not solved.';
                else
                    regime='WARNING: UNCHOKED FLOW POSSIBLE';
                    msg='Displayed choked gas solution is DESIGN ONLY; actual subsonic flow not solved.';
                end
                note=sprintf(['Gas preset properties are approximate and constant. ', ...
                    'P_exit=%.3f psia; P_shock-at-exit=%.3f psia; ', ...
                    'choking-limit P_back=%.3f psia. ', ...
                    'No internal shocks, friction or heat transfer modeled.'], ...
                    Pe/psi,shockExit/psi,pChoke/psi);
                plot2=M;plot2Name='Mach number';
                liquidFlag='';
            else
                % Steady incompressible model: inlet and outlet both at
                % specified static pressure; K is lumped loss based on exit V.
                % Bernoulli: Pin-Pout = rho/2*(Ve^2-Vin^2+K*Ve^2)
                % Vin=Q/Ai, Ve=Q/Ae. Only positive forward flow accepted.
                rh=p.rho;
                denom=(1+p.K)/Ae^2-1/Ai^2;
                assert(denom>0,'Invalid liquid geometry/loss configuration.');
                Q=sqrt(2*(P0-Pa)/(rh*denom));
                V=Q./A;mdot=rh*Q;
                % Distributed loss allocation by normalized distance.
                % Local Bernoulli with loss growing from inlet to exit.
                s=(x-x(1))/(x(end)-x(1));
                P=P0+.5*rh*(V(1)^2-V.^2)-.5*rh*p.K*V(end)^2.*s;
                T=p.T0+zeros(size(x));rho=rh+zeros(size(x));
                Pe=P(end);F=mdot*V(end)+(Pe-Pa)*Ae;
                % This is a gross momentum/pressure flux proxy, NOT net
                % thrust of an installed liquid nozzle (inlet momentum missing).
                M=NaN(size(x));plot2=V/max(V(end),eps);
                plot2Name='Velocity / exit velocity';
                minP=min(P);Pv=p.Pv*1000;
                if minP<=Pv
                    regime='WARNING: CAVITATION RISK';
                    msg='Predicted static pressure reaches/below vapor pressure. Single-phase model invalid.';
                else
                    regime='SINGLE-PHASE LIQUID / NO CAVITATION FLAG';
                    msg='Incompressible Bernoulli flow; diverging section decelerates liquid.';
                end
                Re=rh*max(V)*Dt/max(p.mu,eps);
                note=sprintf(['Liquid: Q=%.6f m^3/s, max velocity=%.2f m/s, ', ...
                    'min pressure=%.3f psia, estimated Re_t=%.3g. ', ...
                    'Temperature held constant; K is an assumed total loss. ', ...
                    'No viscosity-resolved losses, cavitation or phase change solved.'], ...
                    Q,max(V),minP/psi,Re);
                liquidFlag=['Liquid exit area ratio is user-adjustable. ', ...
                    'The ideal force is an outlet momentum-flux proxy, not net nozzle thrust.'];
            end
            D=struct('x',x,'r',r,'A',A,'M',M,'P',P,'T',T,'rho',rho, ...
                'V',V,'mdot',mdot,'F',F,'Pe',Pe,'Pa',Pa,'P0',P0, ...
                'At',At,'Ae',Ae,'De',De,'Lc',Lc,'Ld',Ld, ...
                'kind',kind,'fluid',fluidDrop.Value,'plot2',plot2, ...
                'plot2Name',plot2Name,'regime',regime,'note',note);
            metrics{1}.Text=sprintf('%.1f m/s',V(end));
            metrics{2}.Text=sprintf('%.5f kg/s',mdot);
            metrics{3}.Text=sprintf('%.2f psia',Pe/psi);
            if strcmp(kind,'gas')
                metrics{4}.Text=sprintf('%.3f N',F);
            else
                metrics{4}.Text=sprintf('%.3f N*',F);
            end
            status.Text=[upper(fluidDrop.Value) '  |  ' regime];
            if contains(regime,'WARNING'),status.FontColor=C.warn;else,status.FontColor=C.good;end
            detail.Text=msg;
            info={sprintf('FLUID: %s (%s)',fluidDrop.Value,upper(kind)), ...
                '------------------------------------------------------', ...
                sprintf('Inlet diameter       %10.3f mm',p.Din), ...
                sprintf('Throat diameter      %10.3f mm',p.Dt), ...
                sprintf('Exit diameter        %10.3f mm',De*1000), ...
                sprintf('Throat area          %10.3f mm^2',At*1e6), ...
                sprintf('Exit area            %10.3f mm^2',Ae*1e6), ...
                sprintf('Area ratio Ae/At     %10.4f',Ae/At), ...
                sprintf('Converging length    %10.3f mm',Lc*1000), ...
                sprintf('Diverging length     %10.3f mm',Ld*1000), ...
                sprintf('Exit velocity        %10.3f m/s',V(end)), ...
                sprintf('Exit pressure        %10.3f psia',Pe/psi), ...
                sprintf('Exit temperature     %10.3f K',T(end)), ...
                sprintf('Mass flow            %10.6f kg/s',mdot), ...
                sprintf('Ideal outlet force   %10.3f N',F), ...
                sprintf('Flow regime: %s',regime), ...
                ' ',msg,' ',note};
            if strcmp(kind,'gas')
                info=[info,{sprintf('Exit Mach             %10.4f',M(end)), ...
                    sprintf('Ideal Isp (gross)     %10.3f s',F/(mdot*9.80665))}];
            else
                info=[info,{' ',liquidFlag}];
            end
            resultText.Value=info;
            plotAll();resetParticles();redrawLive();probeChanged(probeSlider,[]);
        catch ME
            uialert(fig,ME.message,'Calculation failed','Icon','error');
        end
    end
    function m=bisectionSub(fun,ar)
        lo=1e-10;hi=1;
        for j=1:90
            mid=(lo+hi)/2;
            if fun(mid)>ar,lo=mid;else,hi=mid;end
        end
        m=(lo+hi)/2;
    end
    function plotAll()
        if isempty(D),return;end
        X=D.x*1000;R=D.r*1000;
        cla(ax(1));plot(ax(1),X,R,'Color',C.blue,'LineWidth',1.8);hold(ax(1),'on');
        plot(ax(1),X,-R,'Color',C.blue,'LineWidth',1.8);
        xline(ax(1),0,'--','Color',C.warn);hold(ax(1),'off');axis(ax(1),'equal');grid(ax(1),'on');
        vals={D.plot2,D.P/psi,D.T,D.V,D.rho};
        for k=2:6
            cla(ax(k));plot(ax(k),X,vals{k-1},'Color',C.blue,'LineWidth',1.8);
            xline(ax(k),0,'--','Color',C.warn);grid(ax(k),'on');
        end
        title(ax(2),D.plot2Name,'Color',C.fg);
    end
    function resetParticles(~,~)
        if isempty(D),return;end
        n=95;phase=rand(1,n);radial=(rand(1,n)*1.8-.9);
        redrawLive();
    end
    function redrawLive(~,~)
        if isempty(D)||~isvalid(flowAx),return;end
        cla(flowAx);hold(flowAx,'on');
        x=D.x*1000;r=D.r*1000;
        switch colorDrop.Value
            case 'Velocity',z=D.V;
            case 'Pressure',z=D.P/psi;
            case 'Temperature',z=D.T;
            case 'Density',z=D.rho;
            otherwise
                z=D.M;
                if strcmp(D.kind,'liquid'),z=D.plot2;end
        end
        if ~strcmp(modeDrop.Value,'Tracers only')
            xx=[x;x];yy=[-r;r];zz=[z;z];
            fieldHandle=surf(flowAx,xx,yy,zeros(size(xx)),zz, ...
                'EdgeColor','none','FaceColor','interp','FaceAlpha',.86);
            view(flowAx,2);colormap(flowAx,parula(256));
            if max(z)>min(z),clim(flowAx,[min(z) max(z)]);end
            colorbar(flowAx);
        end
        plot(flowAx,x,r,'Color',C.fg,'LineWidth',2);
        plot(flowAx,x,-r,'Color',C.fg,'LineWidth',2);
        xline(flowAx,0,'--','Color',C.warn);
        if ~strcmp(modeDrop.Value,'Field only')
            [px,py]=particlePositions();
            scatterHandle=scatter(flowAx,px,py,16,C.fg,'filled');
        else
            scatterHandle=[];
        end
        axis(flowAx,'tight');ylim(flowAx,[-max(r)*1.25 max(r)*1.25]);
        xlabel(flowAx,'Axial position [mm]');ylabel(flowAx,'Radius [mm]');
        hold(flowAx,'off');
    end
    function [px,py]=particlePositions()
        if isempty(phase),px=[];py=[];return;end
        x0=D.x(1);x1=D.x(end);
        % Particle phase is a normalized travel-time coordinate:
        % cumulative dx/V, so tracers move faster in high-V regions.
        t=cumtrapz(D.x,1./max(D.V,1e-8));t=t/max(t(end),eps);
        px=interp1(t,D.x,phase,'linear','extrap')*1000;
        rr=interp1(D.x,D.r,px/1000,'linear','extrap')*1000;
        py=radial.*rr;
        px=max(x0*1000,min(x1*1000,px));
    end
    function togglePlay(~,~)
        if isempty(D),return;end
        if strcmp(tickTimer.Running,'on')
            stop(tickTimer);playBtn.Text='PLAY';
        else
            start(tickTimer);playBtn.Text='PAUSE';
        end
    end
    function tick(~,~)
        if isempty(D)||~isvalid(fig),return;end
        try
            % normalized travel-time traversal; animation time is scaled
            % for visualization and is not real physical elapsed time.
            phase=mod(phase+.005*speedDrop.Value,1);
            if ~isempty(scatterHandle)&&isvalid(scatterHandle)
                [px,py]=particlePositions();
                scatterHandle.XData=px;scatterHandle.YData=py;
            end
            drawnow limitrate nocallbacks;
        catch
            if strcmp(tickTimer.Running,'on'),stop(tickTimer);end
        end
    end
    function probeChanged(src,event)
        if isempty(D),return;end
        if nargin>1 && ~isempty(event) && isprop(event,'Value')
            v=event.Value;
        else
            v=src.Value;
        end
        pos=D.x(1)+v*(D.x(end)-D.x(1));
        vloc=interp1(D.x,D.V,pos);ploc=interp1(D.x,D.P,pos)/psi;
        tloc=interp1(D.x,D.T,pos);
        if strcmp(D.kind,'gas')
            ml=interp1(D.x,D.M,pos);
            probeText.Text=sprintf('x=%.2f mm | M=%.3f | V=%.1f m/s | P=%.2f psia | T=%.1f K', ...
                pos*1000,ml,vloc,ploc,tloc);
        else
            probeText.Text=sprintf('x=%.2f mm | V=%.1f m/s | P=%.2f psia | T=%.1f K', ...
                pos*1000,vloc,ploc,tloc);
        end
    end
    function exportData(~,~)
        if isempty(D),uialert(fig,'Calculate first.','No data');return;end
        [filename,folder]=uiputfile('*.csv','Save flow CSV', ...
            ['Nozzle_' regexprep(D.fluid,'\W','_') '_Flow.csv']);
        if isequal(filename,0),return;end
        [~,base,~]=fileparts(filename);
        try
            x_mm=D.x(:)*1000;radius_mm=D.r(:)*1000;
            area_mm2=D.A(:)*1e6;Mach=D.M(:);
            pressure_psia=D.P(:)/psi;temperature_K=D.T(:);
            velocity_mps=D.V(:);density_kgm3=D.rho(:);
            flowTable=table(x_mm,radius_mm,area_mm2,Mach,pressure_psia, ...
                temperature_K,velocity_mps,density_kgm3);
            writetable(flowTable,fullfile(folder,[base '.csv']));
            x_mm=[x_mm;flipud(x_mm)];
            y_mm=[radius_mm;-flipud(radius_mm)];
            cadTable=table(x_mm,y_mm);
            writetable(cadTable,fullfile(folder,[base '_CAD.csv']));
            uialert(fig,sprintf('Saved:\n%s.csv\n%s_CAD.csv',base,base), ...
                'Export complete','Icon','success');
        catch ME
            uialert(fig,ME.message,'Export failed','Icon','error');
        end
    end
    function closeApp(~,~)
        try
            if strcmp(tickTimer.Running,'on'),stop(tickTimer);end
            delete(tickTimer);
        catch
        end
        delete(fig);
    end
end
