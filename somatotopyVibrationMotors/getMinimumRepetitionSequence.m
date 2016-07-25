function s = getMinimumRepetitionSequence(k, n)
% s = getMinimumRepetitionSequence(k, n) returns a sequence s of length n
% containing integers 1 to k such that all unique pairs of two successive
% integers occur equally often. This minimizes correlations across stimuli
% and makes it easier to extract signals.

% Sequence:
s = zeros(n, 1);

% Matrix to count occurrences of two-digit patterns:
p1 = zeros(k, 1);
p2 = zeros(k);
p_i = repmat(1:k, k, 1)';

s(1) = 1;
p1(1) = 1;
for i = 2:n
    candidates = p1==min(p1);
    p2_ = p2;
    p2_(~candidates, :) = inf;
    [~, s(i)] = min(p2_(:, s(i-1)));
    p1(s(i)) = p1(s(i))+1;
    p2(s(i), s(i-1)) = p2(s(i), s(i-1))+1;
end