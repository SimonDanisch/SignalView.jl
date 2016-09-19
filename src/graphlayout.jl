
"""
Takes a signal and creates a dictionary of unique nodes and
their neighbours from the signal graph.
"""
function to_adjency_dict(s::Signal, adjecency_dict = Dict{Signal, Vector{Any}}(), neighbours = [])
    adjecency_dict[s] = neighbours
    for action in s.actions
        neighour_s = action.recipient.value
        if neighour_s !=nothing && !haskey(adjecency_dict, neighour_s)
            push!(neighbours, neighour_s)
            to_adjency_dict(neighour_s, adjecency_dict)
        end
    end
    for parent_s in s.parents
        if !haskey(adjecency_dict, parent_s)
            to_adjency_dict(parent_s, adjecency_dict, Any[s])
        end
    end
    adjecency_dict
end

"""
Takes the signal `s` and turns it into a adjecency list plus a list of the unique
nodes in the correct order for the adjecency list.
"""
function to_adjency_list(s::Signal)
    dict = to_adjency_dict(s)
    adjecency_list = Vector{Int}[]
    labels = Signal[]
    pos_in_adjecency = Dict{Signal, Int}()
    # Initialize neighbours in adjecency_list
    for (signal, v) in dict
        push!(adjecency_list, Int[])
        push!(labels, signal)
        pos_in_adjecency[signal] = length(adjecency_list)
    end
    # fill neighbours
    for (signal, neighbours) in dict
        neighbourlist = adjecency_list[pos_in_adjecency[signal]]
        for neighbour in neighbours
            push!(neighbourlist, pos_in_adjecency[neighbour])
        end
    end
    adjecency_list, labels
end
