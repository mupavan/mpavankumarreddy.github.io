%rng('default');
rng('shuffle');
%rng(2);

n = 2000;
p_t = 0.75;

alpha = 6;
beta = 2;


parts = 7.5;

error = 0;
max_iter = 10;
iter = 1;
while(iter <= max_iter)

    l_0 = 15;
    budget = l_0*n;
    r = n/10;

    unif = rand(n,1);
    % converting uniform distribution to 1 and -1 with probability p_t

    tasks = (unif <= p_t)*2 - 1;

    p = zeros(0,1);
    % graph = zeros(n,0);
    A = zeros(n,0);
    pj = zeros(0,1);
    % q should mu_p(t|A). The columns correspond to {-1, 1}
    q = zeros(n,1);
    
    while(budget/n > 1)

        fprintf('***********Budget = %d/%d***********\n', budget, l_0*n)

        l = floor(budget/n/parts);
        if(l == 0)
           l = 1; 
        end

        r = n/10;
        m = round(n*l/r);

        display('initialization')    
        % reliablity of workers sampled from beta distribution
        p = [p; 0.1 + 0.9*betarnd(alpha,beta,m,1)];

        % generating a graph - adjacency matrix using configuration model
        left_half = reshape(repmat(1:n,l,1),n*l,[]);
        right_half = reshape(repmat((size(p,1) - m) + 1 : size(p,1),r,1),m*r,[]);

        index = randperm(n*l);
        right_half = right_half(index);

    %     graph = [graph zeros(n, m)];
        A = [A zeros(n, m)];

        for i = 1:(n*l)
    %       graph(left_half(i), right_half(i)) = 1;
          A(left_half(i), right_half(i)) = -tasks(left_half(i));
          if (rand() <= p(right_half(i)))
            A(left_half(i), right_half(i)) = tasks(left_half(i));
          end
        end

        % initialisation
        if(budget == l_0*n)
            for i = 1:n
              q(i) = sum(A(i, :) == -1)/sum(A(i, :) ~= 0);
              %q(i, 1) = 1 - p_t;
              %q(i, 2) = p_t;
            end
        end

        current_predictions = -2*(q >= 0.5)+1;
        successful = sum(tasks == current_predictions);
        fprintf('Majority Voting: %d/%d\n', successful, n);

        pj = [pj; zeros(m, 1)];
        for j = (size(pj,1) - m)+1:size(pj,1)
          dj = find(A(:, j) ~= 0);
    %       pj(j) = sum(q(dj + ((A(dj,j) + 3)/2-1)*n))/numel(dj);
          pj(j) = sum(q(dj).*(A(dj,j)==-1) + (1-q(dj)).*(A(dj,j)==1))/numel(dj);
        end

    % Log-likelihood function
    % L(pj)

        m_total = size(p,1);
        for k = 1:100
          % E-step
          p_vals = [1-pj;pj]';
          for i = 1:n
            di = find(A(i, :) ~= 0);
            ti = 1;
            %prod_plus = prod(p_vals((A(i, di) == ti)*m + di));
            prod_plus = p_t*prod(p_vals((A(i, di) == ti)*m_total + di));
            ti = -1;
            %prod_minus = prod(p_vals((A(i, di) == ti)*m + di));
            prod_minus = (1-p_t)*prod(p_vals((A(i, di) == ti)*m_total + di));
            q(i) = prod_minus / (prod_minus + prod_plus);
    %         q(i, 2) = 1 - q(i, 1);
          end

          % M-step
          for j = 1:size(pj)
            dj = find(A(:, j) ~= 0);
            pj(j) = sum(q(dj).*(A(dj,j)==-1) + (1-q(dj)).*(A(dj,j)==1))/numel(dj);
    %         pj(j) = sum(q(dj + ((A(dj,j) + 3)/2-1)*n))/numel(dj);
          end
        end

        current_predictions = -2*(q >= 0.5)+1;
        successful = sum(tasks == current_predictions);
        fprintf('EM with budget=%d: %d/%d\n', l_0*n - budget + sum(sum(A(:,(size(pj,1) - m)+1:size(pj,1)) ~= 0)), successful, n);

        budget = budget - sum(sum(A(:,(size(pj,1) - m)+1:size(pj,1)) ~= 0));
        fprintf('Budget left=%d\n', budget);
    end
    error = error + (n - successful)/n;
    
    iter = iter + 1;
end

error = error/max_iter

%{
display('removing lowest reliability nodes')
[sm, sm_in] = getNElements(pj, 100);

A(:, sm_in) = 0;
graph(:, sm_in) = 0;
%}