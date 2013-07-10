require 'json'
require 'chef_zero/rest_base'
require 'chef_zero/rest_error_response'

module ChefZero
  module Endpoints
    # /environments/NAME/cookbook_versions
    class EnvironmentCookbookVersionsEndpoint < RestBase
      def post(request)
        cookbook_names = list_data(request, ['cookbooks'])

        # Get the list of cookbooks and versions desired by the runlist
        desired_versions = {}
        run_list = JSON.parse(request.body, :create_additions => false)['run_list']
        run_list.each do |run_list_entry|
          if run_list_entry =~ /(.+)::.+\@(.+)/ || run_list_entry =~ /(.+)\@(.+)/
            raise RestErrorResponse.new(412, "No such cookbook: #{$1}") if !cookbook_names.include?($1)
            raise RestErrorResponse.new(412, "No such cookbook version for cookbook #{$1}: #{$2}") if !list_data(request, ['cookbooks', $1]).include?($2)
            desired_versions[$1] = [ $2 ]
          else
            desired_cookbook = run_list_entry.split('::')[0]
            raise RestErrorResponse.new(412, "No such cookbook: #{desired_cookbook}") if !cookbook_names.include?(desired_cookbook)
            desired_versions[desired_cookbook] = list_data(request, ['cookbooks', desired_cookbook])
          end
        end

        # Filter by environment constraints
        environment = JSON.parse(get_data(request, request.rest_path[0..1]), :create_additions => false)
        environment_constraints = environment['cookbook_versions'] || {}

        desired_versions.each_key do |name|
          desired_versions = filter_by_constraint(desired_versions, name, environment_constraints[name])
        end

        # Depsolve!
        solved = depsolve(request, desired_versions.keys, desired_versions, environment_constraints)
        if !solved
          return raise RestErrorResponse.new(412, "Unsolvable versions!")
        end

        result = {}
        solved.each_pair do |name, versions|
          cookbook = JSON.parse(get_data(request, ['cookbooks', name, versions[0]]), :create_additions => false)
          result[name] = DataNormalizer.normalize_cookbook(cookbook, name, versions[0], request.base_uri, 'MIN')
        end
        json_response(200, result)
      end

      def depsolve(request, unsolved, desired_versions, environment_constraints)
        return nil if desired_versions.values.any? { |versions| versions.empty? }

        # If everything is already
        solve_for = unsolved[0]
        return desired_versions if !solve_for

        # Go through each desired version of this cookbook, starting with the latest,
        # until we find one we can solve successfully with
        sort_versions(desired_versions[solve_for]).each do |desired_version|
          new_desired_versions = desired_versions.clone
          new_desired_versions[solve_for] = [ desired_version ]
          new_unsolved = unsolved[1..-1]

          # Pick this cookbook, and add dependencies
          cookbook_obj = JSON.parse(get_data(request, ['cookbooks', solve_for, desired_version]), :create_additions => false)
          cookbook_metadata = cookbook_obj['metadata'] || {}
          cookbook_dependencies = cookbook_metadata['dependencies'] || {}
          dep_not_found = false
          cookbook_dependencies.each_pair do |dep_name, dep_constraint|
            # If the dep is not already in the list, add it to the list to solve
            # and bring in all environment-allowed cookbook versions to desired_versions
            if !new_desired_versions.has_key?(dep_name)
              new_unsolved = new_unsolved + [dep_name]
              # If the dep is missing, we will try other versions of the cookbook that might not have the bad dep.
              if !exists_data_dir?(request, ['cookbooks', dep_name])
                dep_not_found = true
                break
              end
              new_desired_versions[dep_name] = list_data(request, ['cookbooks', dep_name])
              new_desired_versions = filter_by_constraint(new_desired_versions, dep_name, environment_constraints[dep_name])
            end
            new_desired_versions = filter_by_constraint(new_desired_versions, dep_name, dep_constraint)
          end

          next if dep_not_found

          # Depsolve children with this desired version!  First solution wins.
          result = depsolve(request, new_unsolved, new_desired_versions, environment_constraints)
          return result if result
        end
        return nil
      end

      def sort_versions(versions)
        result = versions.sort_by { |version| Gem::Version.new(version.dup) }
        result.reverse
      end

      def filter_by_constraint(versions, cookbook_name, constraint)
        return versions if !constraint
        constraint = Gem::Requirement.new(constraint)
        new_versions = versions[cookbook_name]
        new_versions = new_versions.select { |version| constraint.satisfied_by?(Gem::Version.new(version.dup)) }
        result = versions.clone
        result[cookbook_name] = new_versions
        result
      end
    end
  end
end
