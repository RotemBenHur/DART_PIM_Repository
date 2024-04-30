%% 1M Reads:

Reads_num = 1e6;
Required_reads_num = 900e6;

num_cyc_linear_WF = 253500; % update with numbers from cycle accurate simulator
num_cyc_affine_WF = 1193400; % update with numbers from cycle accurate simulator 

num_minimizers_reads = 7927597; % Number of minimizers of all the reads

clk_period_aggr = 0.5e-9; %Agressively scaled
clk_period_cons = 2e-9; %Conservatively scaled

%%%%%%%%%%%%%%%%%%%%%%%%%%% WF Iterations and Execution Time %%%%%%%%%%%%%%%%%%%%%%%%%%%

% MAX_READS_PER_CROSSBAR = 500 !

dumped_reads_maxReads500 = 238868;

power = [1:1:6];

crossbar_col_num = 1024;
crossbar_row_num = 128;

linear_buffer_row_num = 16;
affine_buffer_row_num = 2.^power;
read_buffer_row_num = crossbar_row_num - linear_buffer_row_num - affine_buffer_row_num;


num_linear_WF_iter = [0 340 376 448 592 0];
num_affine_WF_iter = [0 85 47 28 18 0];
num_linear_WFs = [0 1109364515 1187193151 1201074533 1207532094 0];
num_affine_WFs = [0 72516185 77515399 78418954 57683686 0];
num_linear_WF_time = num_cyc_linear_WF*num_linear_WF_iter*clk_period_aggr;
num_affine_WF_time = num_cyc_affine_WF*num_affine_WF_iter*clk_period_aggr;

tot_num_WFs = 1287533698;

% Figure - WF Iterations
hf=figure; ax = axes;     

b1 = bar(affine_buffer_row_num,num_linear_WF_iter,'BarWidth',0.9);
xlabel('Number of Rows of Affine Buffer','interpreter','latex','fontsize',16);
ylabel('Number of WF Iterations','interpreter','latex','fontsize',16);
ax.FontSize = 14; 
ax.XAxis.Scale = "log";
ax.TickLabelInterpreter  = 'latex';

hold on
b2 = bar(affine_buffer_row_num,num_affine_WF_iter,'BarWidth',0.6); 

legend('Linear WF Iterations','Affine WF Iterations','interpreter','latex','fontsize',10);


% Figure - Execution Time - 1M Reads
hf=figure; ax = axes;     
b1 = bar(affine_buffer_row_num,num_linear_WF_time,'BarWidth',0.9);
% b1 = bar(MAX_READS_PER_CROSSBAR,num_linear_WF_iter,'BarWidth',0.9);
xlabel('Number of Rows of Affine Buffer','interpreter','latex','fontsize',16);
ylabel('Execution Time [s]','interpreter','latex','fontsize',16);
title('Agressivly Scaled Clock (0.5ns), 1M Reads');
ax.FontSize = 14; 
ax.XAxis.Scale = "log";
ax.TickLabelInterpreter  = 'latex';

hold on
b2 = bar(affine_buffer_row_num,num_affine_WF_time,'BarWidth',0.6); 

legend('Linear WF','Affine WF','interpreter','latex','fontsize',10);


% Figure - Execution Time - 900M Reads
hf=figure; ax = axes; 

num_linear_WF_time_900M = num_linear_WF_time*Required_reads_num/Reads_num;
num_affine_WF_time_900M = num_affine_WF_time*Required_reads_num/Reads_num;
total_execution_time = num_linear_WF_time_900M + num_affine_WF_time_900M;

b1 = bar(affine_buffer_row_num,total_execution_time,'BarWidth',0.9); 


% b1 = bar(MAX_READS_PER_CROSSBAR,num_linear_WF_iter,'BarWidth',0.9);
xlabel('Number of Rows of Affine Buffer','interpreter','latex','fontsize',16);
ylabel('Execution Time [s]','interpreter','latex','fontsize',16);
title('Agressivly Scaled Clock (0.5ns), 900M Reads');
ax.FontSize = 14; 
ax.XAxis.Scale = "log";
ax.TickLabelInterpreter  = 'latex';

hold on
b2 = bar(affine_buffer_row_num,num_linear_WF_time_900M,'BarWidth',0.7);

b3 = bar(affine_buffer_row_num,num_affine_WF_time_900M,'BarWidth',0.5); 



legend('Total','Linear WF','Affine WF','interpreter','latex','fontsize',10);

hold off

%%

%%%%%%%%%%%%%%%%%%%%%%%%%%% Parallelism %%%%%%%%%%%%%%%%%%%%%%%%%%%



