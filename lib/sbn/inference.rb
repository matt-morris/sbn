module Sbn
  class Net
    MCMC_DEFAULT_SAMPLE_COUNT = 2000

  	# Returns a hash containing the estimated posterior probability of each
    # possible state for the specified variable, based on previously-supplied
    # evidence, using the Markov Chain Monte Carlo algorithm. The MCMC algorithm
    # generates each event by making a random change to the preceding event. The
    # next state is generated by randomly sampling a value for one of the
    # nonevidence variables Xi, conditioned on the current values of the
    # variables in the Markov blanket of Xi. MCMC basically wanders randomly
    # around the state space--the space of possible complete
    # assignments--flipping one variable at a time, but keeping the evidence
    # variables fixed. The sampling process works because it settles into a
    # "dynamic equilibrium" in which the long-run fraction of time spent in each
    # state is proportional to its posterior probability.
    # 
    # Optionally accepts a block that receives a number between 0 and 1 indicating
    # the percentage of completion. 
    def query_variable(varname, sample_count = MCMC_DEFAULT_SAMPLE_COUNT, callback = nil)
      # keep track of number of times a state has been observed
      state_frequencies = {}
      varname = varname.to_underscore_sym
      states = @variables[varname].states
      states.each {|s| state_frequencies[s] ||= 0 }

      e = generate_random_event
      relevant_evidence = e.reject {|key, val| @variables[key].set_in_evidence?(@evidence) }

      sample_count.times do |n|
        state = e[varname]
        state_frequencies[state] += 1

        relevant_evidence.each do |vname, vstate|
          e[vname] = @variables[vname].get_random_state_with_markov_blanket(e)
        end
        yield(n / sample_count.to_f) if block_given?
      end

      # normalize results
      magnitude = 0
      returnval = {}
      state_frequencies.each_value {|count| magnitude += count }
      state_frequencies.each {|state, count| returnval[state] = count / magnitude.to_f }
      returnval
    end

  private
    # Returns an event in which variables that are not fixed by the evidence are set
    # to random states whose frequencies (after repeated calls) are consistent
    # with the network's joint probability distribution.
    def generate_random_event
      unset_variables = @variables.reject {|name, variable| variable.set_in_evidence?(@evidence) }
      new_evidence = @evidence.dup
      until unset_variables.empty? do
        settable_variables = unset_variables.reject {|name, variable| !variable.can_be_evaluated?(new_evidence) }
        settable_variables.each do |name, variable|
          unset_variables.delete(name)
          new_evidence[name] = variable.get_random_state(new_evidence)
        end
      end
      new_evidence
    end
  end
end    