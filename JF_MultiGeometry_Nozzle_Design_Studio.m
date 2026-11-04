function JF_MultiGeometry_Nozzle_Design_Studio
% MULTIGEOMETRY_NOZZLE_DIFFUSER_MACH_APP
% Standalone MATLAB UI: converging nozzle, CD nozzle, diffuser.
% Gas: ideal, constant-gamma quasi-1D isentropic branches.
% Liquid: steady incompressible Bernoulli with lumped K loss.
% Animation is a visualization of 1-D fields, NOT CFD.

S = struct(); S.data=[]; S.particles=[]; S.phase=0; S.running=false;
C.bg=[.065 .095 .15]; C.panel=[.11 .15 .22]; C.white=[.94 .97 1];
fig=uifigure('Name','Multi-Fluid Nozzle & Diffuser Simulator','Position',[60 60 1470 860], 'Color',C.bg);
fig.CloseRequestFcn=@closeApp;
root=uigridlayout(fig,[2 2]); root.RowHeight={55,'1x'}; root.ColumnWidth={335,'1x'};
root.Padding=[12 10 12 10]; root.RowSpacing=8; root.ColumnSpacing=10;
head=uilabel(root,'Text','FLOW LAB  |  MULTI-FLUID NOZZLE & DIFFUSER SIMULATOR',...
    'FontSize',21,'FontWeight','bold','FontColor',C.white); head.Layout.Row=1; head.Layout.Column=[1 2];
left=uipanel(root,'Title','CONFIGURATION','BackgroundColor',C.panel,'ForegroundColor',C.white,'FontWeight','bold');
left.Layout.Row=2; left.Layout.Column=1;
lg=uigridlayout(left,[19 2]); lg.RowHeight=[repmat({30},1,16),{38},{38},{'1x'}];
lg.ColumnWidth={155,'1x'}; lg.Padding=[8 8 8 8]; lg.RowSpacing=4;
fluid=makeDrop(1,'Fluid',{'Air','Nitrogen','Helium','Hydrogen','Oxygen','CO2','Water','Ethanol','Glycerol','Custom Gas','Custom Liquid'},'Air');
geom=makeDrop(2,'Geometry',{'Converging nozzle','CD nozzle','Diffuser'},'CD nozzle');
P0=makeNum(3,'Inlet total P (psia)',100);
T0=makeNum(4,'Inlet total T (K)',300);
Pb=makeNum(5,'Back P (psia)',14.5);
Vin=makeNum(6,'Inlet velocity (m/s)',20);
Din=makeNum(7,'Inlet diameter (mm)',20);
Dt=makeNum(8,'Throat/min D (mm)',10);
De=makeNum(9,'Exit diameter (mm)',12);
alpha=makeNum(10,'Converging angle (deg)',20);
beta=makeNum(11,'Diverging angle (deg)',10);
gammaField=makeNum(12,'Gas gamma',1.4);
Rfield=makeNum(13,'Gas R (J/kg/K)',287.05);
rhoField=makeNum(14,'Liquid rho (kg/m3)',998.2);
Kfield=makeNum(15,'Liquid loss K',0.15);
nField=makeNum(16,'Axial samples',200);
calc=uibutton(lg,'push','Text','CALCULATE / UPDATE','FontWeight','bold','BackgroundColor',[.12 .46 .84],'FontColor',[1 1 1],'ButtonPushedFcn',@calculate); calc.Layout.Row=17; calc.Layout.Column=[1 2];
exp=uibutton(lg,'push','Text','EXPORT FLOW + CAD CSV','ButtonPushedFcn',@exportData); exp.Layout.Row=18; exp.Layout.Column=[1 2];
info=uitextarea(lg,'Editable','off','Value',{'Models: ideal gas / incompressible liquid';'Animation is not CFD.'},'BackgroundColor',C.panel,'FontColor',C.white,'FontSize',11);
info.Layout.Row=19; info.Layout.Column=[1 2];

right=uigridlayout(root,[3 1]); right.Layout.Row=2; right.Layout.Column=2;
right.RowHeight={105,'1x',108}; right.RowSpacing=7; right.Padding=[0 0 0 0];
summary=uigridlayout(right,[2 5]); summary.Layout.Row=1; summary.Layout.Column=1;
summary.RowHeight={22,'1x'}; summary.ColumnWidth={'1x','1x','1x','1x','1x'}; summary.Padding=[6 4 6 4]; summary.BackgroundColor=C.panel;
labels={'EXIT MACH','EXIT VELOCITY','MASS FLOW','EXIT PRESSURE','FORCE ESTIMATE'};
vals=cell(1,5);
for j=1:5
    lab=uilabel(summary,'Text',labels{j},'FontSize',11,'FontColor',[.65 .75 .87]); lab.Layout.Row=1;lab.Layout.Column=j;
    vals{j}=uilabel(summary,'Text','--','FontSize',17,'FontWeight','bold','FontColor',C.white);
    vals{j}.Layout.Row=2; vals{j}.Layout.Column=j;
end

tabs=uitabgroup(right); tabs.Layout.Row=2; tabs.Layout.Column=1;
designTab=uitab(tabs,'Title','DESIGN STUDIO'); compareTab=uitab(tabs,'Title','COMPARE DESIGNS'); reportTab=uitab(tabs,'Title','DESIGN REPORT');
flowTab=uitab(tabs,'Title','LIVE FLOW'); plotsTab=uitab(tabs,'Title','SIX PLOTS');
flowGrid=uigridlayout(flowTab,[2 1]);flowGrid.RowHeight={'1x',45};flowGrid.Padding=[5 5 5 5];
axFlow=uiaxes(flowGrid);axFlow.Layout.Row=1; axFlow.Layout.Column=1;
ctrl=uigridlayout(flowGrid,[1 7]);ctrl.Layout.Row=2;ctrl.ColumnWidth={65,65,65,95,90,100,'1x'};ctrl.Padding=[0 0 0 0];
uibutton(ctrl,'push','Text','PLAY','ButtonPushedFcn',@playFlow);
uibutton(ctrl,'push','Text','PAUSE','ButtonPushedFcn',@pauseFlow);
uibutton(ctrl,'push','Text','RESET','ButtonPushedFcn',@resetFlow);
colorMode=uidropdown(ctrl,'Items',{'Mach number','Velocity','Pressure','Temperature','Density'},'Value','Mach number','ValueChangedFcn',@renderFlow);
speedLabel=uilabel(ctrl,'Text','Speed'); %#ok<NASGU>
speed=uislider(ctrl,'Limits',[.2 4],'Value',1);
probe=uislider(ctrl,'Limits',[0 1],'Value',.5,'ValueChangedFcn',@renderFlow);

pg=uigridlayout(plotsTab,[3 2]);pg.RowHeight={'1x','1x','1x'};pg.ColumnWidth={'1x','1x'};pg.Padding=[4 4 4 4];
axesPlots=gobjects(1,6);
for j=1:6
    axesPlots(j)=uiaxes(pg); axesPlots(j).Layout.Row=ceil(j/2);axesPlots(j).Layout.Column=mod(j-1,2)+1;
end
% ADDITIVE DESIGN STUDIO: existing calculator controls and tabs are unchanged.
dg=uigridlayout(designTab,[2 2]); dg.RowHeight={'1x',52}; dg.ColumnWidth={350,'1x'};dg.Padding=[10 10 10 10];
dp=uipanel(dg,'Title','REQUIREMENTS -> AUTO SIZE');dp.Layout.Row=1;dp.Layout.Column=1;
dpg=uigridlayout(dp,[12 2]);dpg.RowHeight=[repmat({31},1,11),{'1x'}];dpg.ColumnWidth={160,'1x'};
designMode=uidropdown(dpg,'Items',{'Target exit Mach','Target mass flow','Specified throat diameter'},'Value','Target exit Mach'); designMode.Layout.Row=1;designMode.Layout.Column=2;
lab=uilabel(dpg,'Text','Sizing method');lab.Layout.Row=1;lab.Layout.Column=1;
targetMach=designNum(2,'Target exit Mach',2.5);
targetMdot=designNum(3,'Target mass flow (kg/s)',.02);
targetDt=designNum(4,'Throat diameter (mm)',10);
designInlet=designNum(5,'Inlet diameter (mm)',20);
designAngle=designNum(6,'Converging angle (deg)',20);
designDivAngle=designNum(7,'Diverging angle (deg)',12);
designRatio=designNum(8,'Liquid exit/throat A ratio',1.5);
designVelocity=designNum(9,'Diffuser inlet speed (m/s)',20);
designExit=designNum(10,'Diffuser exit/inlet A ratio',2);
lab=uilabel(dpg,'Text','Fluid & pressure: use left panel','WordWrap','on');lab.Layout.Row=11;lab.Layout.Column=[1 2];
designNotes=uitextarea(dpg,'Editable','off','Value',{'Choose a design method, then click GENERATE DESIGN.'});designNotes.Layout.Row=12;designNotes.Layout.Column=[1 2];
designAx=uiaxes(dg);designAx.Layout.Row=1;designAx.Layout.Column=2;
btn=uibutton(dg,'push','Text','GENERATE DESIGN + ANALYZE','FontWeight','bold','BackgroundColor',[.12 .46 .84],'FontColor',[1 1 1],'ButtonPushedFcn',@generateDesign);btn.Layout.Row=2;btn.Layout.Column=[1 2];

cg=uigridlayout(compareTab,[2 1]);cg.RowHeight={48,'1x'};
cb=uibutton(cg,'push','Text','SAVE CURRENT DESIGN TO COMPARISON','ButtonPushedFcn',@saveComparison);cb.Layout.Row=1;
comparisonTable=uitable(cg,'ColumnName',{'Design','Fluid','Geometry','Exit Mach','Exit speed m/s','Mass flow kg/s','Exit pressure psia','Force estimate N','Length mm','Exit D mm'},'Data',cell(0,10));comparisonTable.Layout.Row=2;
S.comparison=cell(0,10);
rg=uigridlayout(reportTab,[2 1]);rg.RowHeight={'1x',44};
reportText=uitextarea(rg,'Editable','off','Value',{'Calculate or generate a design to see its engineering summary.'},'FontName','Courier New');reportText.Layout.Row=1;
rb=uibutton(rg,'push','Text','EXPORT DESIGN REPORT (.txt)','ButtonPushedFcn',@exportReport);rb.Layout.Row=2;

status=uitextarea(right,'Editable','off','Value',{'Ready. Set geometry, fluid and operating conditions.'},'BackgroundColor',C.panel,'FontColor',C.white,'FontSize',12);
status.Layout.Row=3;status.Layout.Column=1;
fluid.ValueChangedFcn=@fluidChanged; geom.ValueChangedFcn=@geometryChanged;
% Shared dimensions: either panel immediately updates the other panel.
Din.ValueChangedFcn=@syncFromConfiguration;
Dt.ValueChangedFcn=@syncFromConfiguration;
alpha.ValueChangedFcn=@syncFromConfiguration;
beta.ValueChangedFcn=@syncFromConfiguration;
Vin.ValueChangedFcn=@syncFromConfiguration;
designInlet.ValueChangedFcn=@syncFromDesign;
targetDt.ValueChangedFcn=@syncFromDesign;
designAngle.ValueChangedFcn=@syncFromDesign;
designDivAngle.ValueChangedFcn=@syncFromDesign;
designVelocity.ValueChangedFcn=@syncFromDesign;
fluidChanged();geometryChanged();
syncFromConfiguration();
% Initial default: target CD exit diameter corresponds roughly to Me=1.5
De.Value=10*sqrt(areaMach(1.5,1.4));
calculate();

    function e=designNum(row,label,value)
        l=uilabel(dpg,'Text',label,'FontSize',11);l.Layout.Row=row;l.Layout.Column=1;
        e=uieditfield(dpg,'numeric','Value',value);e.Layout.Row=row;e.Layout.Column=2;
    end
    function syncFromConfiguration(varargin)
        % Configuration is authoritative for the current physical geometry.
        % Setting Value programmatically does not fire ValueChangedFcn.
        designInlet.Value=Din.Value;
        targetDt.Value=Dt.Value;
        designAngle.Value=alpha.Value;
        designDivAngle.Value=beta.Value;
        designVelocity.Value=Vin.Value;
    end
    function syncFromDesign(varargin)
        % Design Studio edits also update the same physical geometry.
        Din.Value=designInlet.Value;
        Dt.Value=targetDt.Value;
        alpha.Value=designAngle.Value;
        beta.Value=designDivAngle.Value;
        Vin.Value=designVelocity.Value;
    end
    function generateDesign(varargin)
        try
            % Always read the CURRENT Configuration dimensions, even if
            % MATLAB has not dispatched a ValueChanged callback yet.
            syncFromConfiguration();
            [isGas,g,R,rl]=properties();
            if ~(designInlet.Value>0 && targetDt.Value>0 && targetMdot.Value>0 && ...
                    designAngle.Value>0 && designAngle.Value<90 && designDivAngle.Value>0 && designDivAngle.Value<90)
                error('Use positive diameters/flow and wall angles between 0 and 90 degrees.');
            end
            Din.Value=designInlet.Value;
            alpha.Value=designAngle.Value;beta.Value=designDivAngle.Value;
            if strcmp(geom.Value,'Diffuser')
                if designExit.Value<=1,error('Diffuser exit/inlet area ratio must exceed 1.');end
                Vin.Value=designVelocity.Value;
                if Vin.Value<=0,error('Diffuser requires positive inlet velocity.');end
                Dt.Value=Din.Value;
                De.Value=Din.Value*sqrt(designExit.Value);
                msg='Diffuser geometry sized from inlet diameter and exit/inlet area ratio. Inlet velocity controls the gas solution.';
            elseif isGas
                if strcmp(designMode.Value,'Target mass flow')
                    % Choked ideal-gas throat sizing. Pressure check remains in calculate().
                    Ppa=P0.Value*6894.757293;
                    if Ppa<=Pb.Value*6894.757293,error('Nozzle needs P0 greater than back pressure.');end
                    coeff=Ppa*sqrt(g/(R*T0.Value))*(2/(g+1))^((g+1)/(2*(g-1)));
                    throatArea=targetMdot.Value/coeff;
                    Dt.Value=1000*sqrt(4*throatArea/pi);
                    msg='Throat sized for the requested mass flow assuming choking. Verify operating warnings.';
                else
                    Dt.Value=targetDt.Value;
                    msg='Throat diameter taken from the design input.';
                end
                if strcmp(geom.Value,'Converging nozzle')
                    De.Value=Dt.Value;
                    msg=[msg ' Converging nozzle exit Mach cannot exceed 1.'];
                else
                    if targetMach.Value<=1,error('Supersonic CD design requires target exit Mach > 1.');end
                    De.Value=Dt.Value*sqrt(areaMach(targetMach.Value,g));
                    msg=[msg ' Exit area sized for target supersonic Mach; actual flow depends on back pressure.'];
                end
            else
                % Incompressible liquid sizing: no Mach design; use area ratio.
                if designRatio.Value<=1 && strcmp(geom.Value,'CD nozzle')
                    error('CD liquid exit/throat area ratio must exceed 1.');
                end
                if strcmp(designMode.Value,'Target mass flow')
                    Pdiff=(P0.Value-Pb.Value)*6894.757293;
                    if Pdiff<=0,error('Liquid requires inlet total pressure above back pressure.');end
                    Ve=sqrt(2*Pdiff/(rl*(1+Kfield.Value)));
                    exitArea=targetMdot.Value/(rl*Ve);
                    De.Value=1000*sqrt(4*exitArea/pi);
                    if strcmp(geom.Value,'CD nozzle')
                        Dt.Value=De.Value/sqrt(designRatio.Value);
                    else
                        Dt.Value=De.Value;
                    end
                    msg='Liquid exit sized for target mass flow using incompressible Bernoulli with lumped loss K.';
                else
                    Dt.Value=targetDt.Value;
                    if strcmp(geom.Value,'CD nozzle')
                        De.Value=Dt.Value*sqrt(designRatio.Value);
                    else
                        De.Value=Dt.Value;
                    end
                    msg='Liquid geometry sized from diameters and area ratio; Mach is not a liquid design input.';
                end
            end
            if Din.Value<=Dt.Value && ~strcmp(geom.Value,'Diffuser')
                error('Calculated throat/exit diameter must be smaller than inlet. Increase inlet diameter or reduce target mass flow.');
            end
            if strcmp(geom.Value,'CD nozzle') && De.Value<=Dt.Value
                error('CD exit diameter must exceed throat diameter.');
            end
            designNotes.Value={msg,sprintf('Inlet D %.3f mm | throat D %.3f mm | exit D %.3f mm',Din.Value,Dt.Value,De.Value)};
            syncFromConfiguration(); % publish auto-sized dimensions to both panels
            calculate();
            if ~isempty(S.data),tabs.SelectedTab=designTab;end
        catch ME
            uialert(fig,ME.message,'Design input error');
        end
    end
    function updateDesignDrawing()
        if isempty(S.data),return;end
        d=S.data;ax=designAx;cla(ax);
        xx=d.x*1000;rr=d.r*1000;
        fill(ax,[xx fliplr(xx)],[rr -fliplr(rr)],[.18 .55 .88],'FaceAlpha',.16,'EdgeColor','none');hold(ax,'on');
        plot(ax,xx,rr,'Color',[.12 .6 .95],'LineWidth',2.5);
        plot(ax,xx,-rr,'Color',[.12 .6 .95],'LineWidth',2.5);
        [~,idx]=min(d.A);xline(ax,xx(idx),'--','Minimum area');
        axis(ax,'equal');grid(ax,'on');hold(ax,'off');
        title(ax,sprintf('%s | Inlet %.2f mm, min %.2f mm, exit %.2f mm',geom.Value,2*rr(1),2*min(rr),2*rr(end)));
        xlabel(ax,'Axial position (mm)');ylabel(ax,'Radius (mm)');
    end
    function updateReport()
        if isempty(S.data),return;end
        d=S.data;[~,ii]=min(d.A);
        if d.isGas
            machLine=sprintf('Mach inlet/minimum/exit: %.4f / %.4f / %.4f',d.M(1),d.M(ii),d.M(end));
        else
            machLine='Mach: N/A (incompressible liquid model)';
        end
        reportText.Value={...
            'MULTI-GEOMETRY NOZZLE / DIFFUSER DESIGN REPORT',...
            ['Fluid: ' fluid.Value],['Geometry: ' geom.Value],...
            sprintf('Inlet total pressure: %.4f psia | Back pressure: %.4f psia',P0.Value,Pb.Value),...
            sprintf('Inlet temperature: %.2f K',T0.Value),...
            sprintf('Inlet diameter: %.4f mm',2*d.r(1)*1000),...
            sprintf('Minimum diameter: %.4f mm',2*min(d.r)*1000),...
            sprintf('Exit diameter: %.4f mm',2*d.r(end)*1000),...
            sprintf('Total axial length: %.4f mm',(d.x(end)-d.x(1))*1000),...
            sprintf('Exit/minimum area ratio: %.5f',d.A(end)/min(d.A)),...
            machLine,...
            sprintf('Exit speed: %.4f m/s | Exit pressure: %.4f psia',d.V(end),d.P(end)/6894.757293),...
            sprintf('Mass flow: %.6f kg/s | Force estimate: %.4f N',d.mdot,d.force),...
            ['Warning: ' d.warning],...
            'ASSUMPTIONS: quasi-1D ideal gas or incompressible liquid.',...
            'No internal shock solution, CFD, cavitation, or viscous separation.',...
            'Gas CD supersonic branch may be a design-only result.'};
    end
    function exportReport(varargin)
        if isempty(S.data),uialert(fig,'Calculate a design first.','No design');return;end
        [fn,folder]=uiputfile('*.txt','Export design report','Nozzle_Design_Report.txt');
        if isequal(fn,0),return;end
        fid=fopen(fullfile(folder,fn),'w');
        if fid<0,uialert(fig,'Could not open report file.','Export error');return;end
        for jj=1:numel(reportText.Value),fprintf(fid,'%s\n',reportText.Value{jj});end
        fclose(fid);
    end
    function saveComparison(varargin)
        if isempty(S.data),uialert(fig,'Calculate a design first.','No design');return;end
        d=S.data;
        if d.isGas,exitM=d.M(end);else,exitM=NaN;end
        row={sprintf('Design %d',size(S.comparison,1)+1),fluid.Value,geom.Value,exitM,...
            d.V(end),d.mdot,d.P(end)/6894.757293,d.force,(d.x(end)-d.x(1))*1000,2*d.r(end)*1000};
        S.comparison(end+1,:)=row;
        comparisonTable.Data=S.comparison;
    end
    function e=makeNum(row,label,value)
        l=uilabel(lg,'Text',label,'FontColor',C.white,'FontSize',11);l.Layout.Row=row;l.Layout.Column=1;
        e=uieditfield(lg,'numeric','Value',value);e.Layout.Row=row;e.Layout.Column=2;
    end
    function e=makeDrop(row,label,items,value)
        l=uilabel(lg,'Text',label,'FontColor',C.white,'FontSize',11);l.Layout.Row=row;l.Layout.Column=1;
        e=uidropdown(lg,'Items',items,'Value',value);e.Layout.Row=row;e.Layout.Column=2;
    end
    function fluidChanged(varargin)
        [isGas,g,r,rl]=properties();
        gammaField.Value=g;Rfield.Value=r;rhoField.Value=rl;
        gammaField.Enable=onoff(isGas && strcmp(fluid.Value,'Custom Gas'));
        Rfield.Enable=onoff(isGas && strcmp(fluid.Value,'Custom Gas'));
        rhoField.Enable=onoff(~isGas && strcmp(fluid.Value,'Custom Liquid'));
        Kfield.Enable=onoff(~isGas);
    end
    function geometryChanged(varargin)
        switch geom.Value
            case 'Converging nozzle'
                De.Value=Dt.Value;
            case 'Diffuser'
                Dt.Value=Din.Value;
                De.Value=max(De.Value,Din.Value*1.5);
        end
        syncFromConfiguration();
    end
    function [isGas,g,r,rl]=properties()
        g=1.4;r=287.05;rl=998.2;
        switch fluid.Value
            case 'Air',g=1.4;r=287.05;
            case 'Nitrogen',g=1.4;r=296.8;
            case 'Helium',g=1.667;r=2077.1;
            case 'Hydrogen',g=1.405;r=4124;
            case 'Oxygen',g=1.395;r=259.84;
            case 'CO2',g=1.289;r=188.9;
            case 'Water',rl=998.2;
            case 'Ethanol',rl=789;
            case 'Glycerol',rl=1260;
            case 'Custom Gas',g=gammaField.Value;r=Rfield.Value;
            case 'Custom Liquid',rl=rhoField.Value;
        end
        isGas=contains(fluid.Value,'Gas') || ismember(fluid.Value,{'Air','Nitrogen','Helium','Hydrogen','Oxygen','CO2'});
    end
    function calculate(varargin)
        try
            syncFromConfiguration(); % keep Design Studio in sync after manual analysis
            [isGas,g,R,rl]=properties();
            if ~(P0.Value>0 && Pb.Value>0 && T0.Value>0 && Din.Value>0 && Dt.Value>0 && De.Value>0 && ...
                    alpha.Value>0 && alpha.Value<90 && beta.Value>0 && beta.Value<90 && nField.Value>=30 && ...
                    nField.Value<=2000 && nField.Value==floor(nField.Value))
                error('Use positive physical inputs, angles between 0 and 90 degrees, and 30-2000 integer samples.');
            end
            if isGas && ~(g>1 && R>0),error('Gas gamma must exceed 1 and R must be positive.');end
            if ~isGas && ~(rl>0 && Kfield.Value>=0),error('Liquid density must be positive and K nonnegative.');end
            if Vin.Value<0,error('Inlet velocity cannot be negative.');end
            di=Din.Value/1000;dt=Dt.Value/1000;de=De.Value/1000;
            switch geom.Value
                case 'Converging nozzle'
                    if di<=de,error('Converging nozzle requires inlet diameter > exit diameter.');end
                    L=(di-de)/2/tand(alpha.Value);
                    x=linspace(0,L,nField.Value); rad=di/2-(di-de)/2*x/L;
                case 'CD nozzle'
                    if ~(di>dt && de>dt),error('CD nozzle requires inlet and exit diameters > throat diameter.');end
                    L1=(di-dt)/2/tand(alpha.Value);L2=(de-dt)/2/tand(beta.Value);
                    n1=max(20,round(nField.Value*L1/(L1+L2)));n2=max(20,nField.Value-n1+1);
                    xd=linspace(0,L2,n2);rd=linspace(dt/2,de/2,n2);
                    x=[linspace(0,L1,n1),L1+xd(2:end)];
                    rad=[linspace(di/2,dt/2,n1),rd(2:end)];
                case 'Diffuser'
                    if de<=di,error('Diffuser requires exit diameter > inlet diameter.');end
                    L=(de-di)/2/tand(beta.Value);
                    x=linspace(0,L,nField.Value);rad=di/2+(de-di)/2*x/L;
            end
            A=pi*rad.^2;Ai=A(1);Ae=A(end);P0pa=P0.Value*6894.757293;Pbpa=Pb.Value*6894.757293;
            warningText=''; valid=true;
            if isGas
                % Nozzle: reservoir total pressure + downstream pressure.
                % Diffuser: inlet total pressure + specified inlet velocity.
                if strcmp(geom.Value,'Diffuser')
                    if Vin.Value<=0,error('Gas diffuser needs a positive inlet velocity.');end
                    cp=g*R/(g-1); h=cp*T0.Value;
                    % Solve inlet Mach from V^2 = gamma R T M^2 and T0=T(1+c M^2)
                    ci=(g-1)/2; q=Vin.Value^2/(g*R*T0.Value);
                    if q>=1/ci,error('Inlet velocity exceeds ideal maximum for specified T0.');end
                    Mi=sqrt(q/(1-ci*q));
                    if Mi>=1,error('This diffuser model supports only subsonic gas inlet flow.');end
                    AiStar=Ai/areaMach(Mi,g);
                    if min(A)<AiStar,error('Area too small for assumed subsonic diffuser flow.');end
                    M=arrayfun(@(ar) rootMach(ar/AiStar,g,false),A);
                    P=P0pa*(1+ci*M.^2).^(-g/(g-1));
                    T=T0.Value./(1+ci*M.^2);rho=P./(R*T);V=M.*sqrt(g*R*T);
                    mdot=rho(1)*Ai*V(1);
                    if abs(P(end)-Pbpa)/Pbpa>.05
                        warningText='Back pressure differs from predicted exit pressure. Diffuser inlet state and back pressure are not simultaneously enforced.';
                    end
                else
                    % For unchoked flow, determine exit Mach from exit static pressure.
                    % For choked flow, take sonic at min area and supersonic CD branch.
                    Amin=min(A); ratio=Ae/Amin;
                    MsubExit=rootMach(ratio,g,false);
                    PcritBack=P0pa*(1+(g-1)/2*MsubExit^2)^(-g/(g-1));
                    choked=Pbpa<=PcritBack;
                    if choked
                        Astar=Amin;
                        M=zeros(size(A));
                        [~,ithroat]=min(A);
                        for ii=1:numel(A)
                            useSup=strcmp(geom.Value,'CD nozzle') && ii>ithroat;
                            M(ii)=rootMach(A(ii)/Astar,g,useSup);
                        end
                        if strcmp(geom.Value,'CD nozzle')
                            Me=M(end);PeIso=P0pa*(1+(g-1)/2*Me^2)^(-g/(g-1));
                            PshockExit=PeIso*(1+2*g/(g+1)*(Me^2-1));
                            if Pbpa>PshockExit*(1+1e-8)
                                warningText='Internal normal shock likely: displayed supersonic profile is a DESIGN branch, not the actual solution.';valid=false;
                            elseif Pbpa>PeIso*1.02
                                warningText='Overexpanded: external compression/shocks may occur.';
                            elseif Pbpa<PeIso*.98
                                warningText='Underexpanded: external expansion may occur.';
                            end
                        else
                            PeIso=P0pa*(2/(g+1))^(g/(g-1));
                            if Pbpa<PeIso
                                warningText='Choked converging nozzle: exit pressure is critical; external jet adjusts to ambient.';
                            end
                        end
                    else
                        if Pbpa>=P0pa,error('For a nozzle, back pressure must be less than inlet stagnation pressure.');end
                        Mex=sqrt(2/(g-1)*((P0pa/Pbpa)^((g-1)/g)-1));
                        if Mex>=1,error('Unchoked branch calculation failed.');end
                        Astar=Ae/areaMach(Mex,g);
                        M=arrayfun(@(ar) rootMach(ar/Astar,g,false),A);
                        warningText='Unchoked subsonic nozzle flow.';
                    end
                    T=T0.Value./(1+(g-1)/2*M.^2);
                    P=P0pa*(1+(g-1)/2*M.^2).^(-g/(g-1));
                    rho=P./(R*T);V=M.*sqrt(g*R*T);
                    mdot=rho(1)*Ai*V(1);
                end
                force=mdot*(V(end)-V(1))+(P(end)-Pbpa)*Ae;
                mLabel='Mach number'; mProfile=M;
            else
                % Liquid: upstream stagnation pressure, outlet static Pb.
                % Inlet velocity input is not imposed for liquids; flow is pressure-driven.
                % Bernoulli: P0 - Pb = .5 rho Ve^2 * (1 + K)
                % Here K is referenced to exit dynamic pressure.
                if P0pa<=Pbpa,error('Liquid model needs inlet total pressure > back pressure.');end
                Ve=sqrt(2*(P0pa-Pbpa)/(rl*(1+Kfield.Value)));
                mdot=rl*Ae*Ve;V=mdot./(rl*A);
                % Pressure profile from total pressure minus local dynamic head
                % and accumulated lumped losses (distributed linearly in x).
                f=(x-x(1))/max(x(end)-x(1),eps);
                P=P0pa-.5*rl*V.^2-.5*rl*Kfield.Value*Ve^2.*f;
                T=T0.Value*ones(size(x));rho=rl*ones(size(x));
                M=nan(size(x));mProfile=V/V(end);mLabel='V / Vexit';
                if min(P)<2000
                    warningText='Very low static pressure: cavitation risk. Vapor pressure is not modeled.';
                end
                force=mdot*(V(end)-V(1))+(P(end)-Pbpa)*Ae;
                if strcmp(geom.Value,'CD nozzle')
                    warningText=strtrim([warningText ' Liquid decelerates after the throat; there is no supersonic branch.']);
                end
            end
            S.data=struct('fluidName',fluid.Value,'geometryName',geom.Value,'x',x,'r',rad,'A',A,'M',M,'P',P,'T',T,'rho',rho,'V',V,'mdot',mdot,...
                'force',force,'isGas',isGas,'valid',valid,'mProfile',mProfile,'mLabel',mLabel,'warning',warningText);
            if isGas
                vals{1}.Text=sprintf('%.3f',M(end));
            else
                vals{1}.Text='N/A';
            end
            vals{2}.Text=sprintf('%.2f m/s',V(end));
            vals{3}.Text=sprintf('%.5f kg/s',mdot);
            vals{4}.Text=sprintf('%.2f psia',P(end)/6894.757293);
            vals{5}.Text=sprintf('%.3f N',force);
            if isempty(warningText),warningText='Ideal model calculated. No flow-regime warning.';end
            if isGas
                [~,throatIndex]=min(A);
                machText=sprintf('M inlet = %.4f   |   M throat/min area = %.4f   |   M exit = %.4f',M(1),M(throatIndex),M(end));
            else
                machText='Mach number: N/A (incompressible liquid approximation)';
            end
            status.Value={sprintf('%s  |  %s  |  %s',fluid.Value,geom.Value,tern(isGas,'Compressible gas','Incompressible liquid')),...
                machText,warningText,'Force estimate uses momentum change and exit pressure term; not a complete nozzle force balance.'};
            drawPlots();resetFlow();updateDesignDrawing();updateReport();
        catch ME
            status.Value={['ERROR: ' ME.message]};
            uialert(fig,ME.message,'Calculation error');
        end
    end
    function drawPlots()
        d=S.data;xx=d.x*1000;
        names={'Nozzle / Diffuser Geometry',d.mLabel,'Static Pressure (psia)','Static Temperature (K)','Velocity (m/s)','Density (kg/m^3)'};
        yy={d.r*1000,d.mProfile,d.P/6894.757293,d.T,d.V,d.rho};
        for j=1:6
            ax=axesPlots(j);cla(ax);
            if j==1
                plot(ax,xx,yy{j},'Color',[.13 .67 .94],'LineWidth',2);hold(ax,'on');
                plot(ax,xx,-yy{j},'Color',[.13 .67 .94],'LineWidth',2);hold(ax,'off');
                ylabel(ax,'Radius (mm)');
            else
                plot(ax,xx,yy{j},'Color',[.13 .67 .94],'LineWidth',1.8);
                if j==2 && d.isGas
                    hold(ax,'on');yline(ax,1,'--','Mach 1');hold(ax,'off');
                    ylabel(ax,'Mach number');
                end
            end
            title(ax,names{j});xlabel(ax,'Axial position (mm)');grid(ax,'on');
        end
    end
    function renderFlow(varargin)
        if isempty(S.data),return;end
        d=S.data;ax=axFlow;cla(ax);hold(ax,'on');
        x=d.x*1000;r=d.r*1000;
        switch colorMode.Value
            case 'Mach number'
                if d.isGas,field=d.M;unit='Mach';else,field=d.V;unit='m/s (liquid)';end
            case 'Velocity',field=d.V;unit='m/s';
            case 'Pressure',field=d.P/6894.757293;unit='psia';
            case 'Temperature',field=d.T;unit='K';
            otherwise,field=d.rho;unit='kg/m^3';
        end
        % Pseudocolor cross section: each axial slice uses 1-D solution.
        yMax=max(r)*1.2;Y=linspace(-yMax,yMax,90);
        Z=repmat(field(:)',numel(Y),1);
        mask=abs(Y(:))>r(:)';Z(mask)=nan;
        imagesc(ax,x,Y,Z);set(ax,'YDir','normal');colormap(ax,turbo);colorbar(ax);
        plot(ax,x,r,'w','LineWidth',2.2);plot(ax,x,-r,'w','LineWidth',2.2);
        if ~isempty(S.particles)
            scatter(ax,S.particles(:,1)*1000,S.particles(:,2)*1000,10,'w','filled','MarkerFaceAlpha',.75);
        end
        xp=x(1)+probe.Value*(x(end)-x(1));
        [~,idx]=min(abs(x-xp));
        plot(ax,[xp xp],[-r(idx) r(idx)],'--','Color',[1 .8 .2],'LineWidth',1.3);
        if d.isGas
            probeText=sprintf('M=%.3f | V=%.1f m/s | P=%.2f psia | T=%.1f K',...
                d.M(idx),d.V(idx),d.P(idx)/6894.757293,d.T(idx));
        else
            probeText=sprintf('M=N/A (liquid) | V=%.1f m/s | P=%.2f psia | T=%.1f K',...
                d.V(idx),d.P(idx)/6894.757293,d.T(idx));
        end
        title(ax,sprintf('%s (%s) | x=%.1f mm | %s',colorMode.Value,unit,xp,probeText));
        xlabel(ax,'Axial position (mm)');ylabel(ax,'Radius (mm)');
        xlim(ax,[x(1) x(end)]);ylim(ax,[-yMax yMax]);
        hold(ax,'off');
    end
    function resetFlow(varargin)
        S.running=false;S.phase=0;
        if isempty(S.data),return;end
        d=S.data;np=140;
        rng(10);
        S.particles=[d.x(1)+(d.x(end)-d.x(1))*rand(np,1),zeros(np,1)];
        for k=1:np
            rr=interp1(d.x,d.r,S.particles(k,1));
            S.particles(k,2)=(2*rand-1)*rr*.88;
        end
        renderFlow();
    end
    function playFlow(varargin)
        if isempty(S.data)||S.running,return;end
        S.running=true;
        % Cooperative loop: UI events (including Pause) processed by drawnow.
        while S.running && isvalid(fig)
            d=S.data; p=S.particles;
            if isempty(p),break;end
            v=interp1(d.x,d.V,p(:,1),'linear','extrap');
            % Visual clock scaling, not physical real-time playback.
            dt=(d.x(end)-d.x(1))/max(max(d.V),1)/120*speed.Value;
            oldX=p(:,1);newX=oldX+max(v,0)*dt;
            reset=newX>d.x(end);newX(reset)=d.x(1);
            oldR=interp1(d.x,d.r,oldX,'linear','extrap');
            newR=interp1(d.x,d.r,newX,'linear','extrap');
            p(:,2)=p(:,2).*newR./max(oldR,eps);
            p(reset,2)=(2*rand(sum(reset),1)-1)*d.r(1)*.88;
            p(:,1)=newX;S.particles=p;
            renderFlow();drawnow limitrate;
            pause(.025);
        end
    end
    function pauseFlow(varargin),S.running=false;end
    function exportData(varargin)
        if isempty(S.data),uialert(fig,'Calculate first.','No data');return;end
        d=S.data;
        [f,path]=uiputfile('*.csv','Save flow data','MultiGeometry_Flow.csv');
        if isequal(f,0),return;end
        flow=table(d.x(:)*1000,d.r(:)*1000,d.A(:)*1e6,d.M(:),d.P(:)/6894.757293,...
            d.T(:),d.V(:),d.rho(:),'VariableNames',...
            {'x_mm','radius_mm','area_mm2','Mach','pressure_psia','temperature_K','velocity_mps','density_kgm3'});
        writetable(flow,fullfile(path,f));
        [~,base,~]=fileparts(f);
        contour=table([d.x(:);flipud(d.x(:))]*1000,[d.r(:);-flipud(d.r(:))]*1000,...
            'VariableNames',{'x_mm','y_mm'});
        writetable(contour,fullfile(path,[base '_CAD.csv']));
        status.Value={['Exported: ' fullfile(path,f)],['CAD: ' fullfile(path,[base '_CAD.csv'])]};
    end
    function closeApp(varargin)
        S.running=false;delete(fig);
    end
end

function a=areaMach(M,g)
a=(1./M).*((2/(g+1)).*(1+(g-1).*M.^2/2)).^((g+1)/(2*(g-1)));
end
function m=rootMach(ar,g,sup)
if ar<1-1e-9,error('Area ratio below unity on isentropic branch.');end
if abs(ar-1)<1e-10,m=1;return;end
if sup
    lo=1;hi=2;
    while areaMach(hi,g)<ar,hi=hi*2;end
    for k=1:70
        mid=(lo+hi)/2;
        if areaMach(mid,g)<ar,lo=mid;else,hi=mid;end
    end
else
    lo=1e-12;hi=1;
    for k=1:70
        mid=(lo+hi)/2;
        if areaMach(mid,g)>ar,lo=mid;else,hi=mid;end
    end
end
m=(lo+hi)/2;
end
function s=onoff(tf)
if tf,s='on';else,s='off';end
end
function s=tern(tf,a,b)
if tf,s=a;else,s=b;end
end
