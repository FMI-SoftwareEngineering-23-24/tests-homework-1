#!/bin/bash

results_dir_name="test-results"
timeout=10

if ! mkdir "${results_dir_name}"; then
	echo "\"${results_dir_name}\" directory cannot be created" >&2
	exit 100
fi

tests_dir=$(dirname "$(realpath $0)")

tasks="$(find "$tests_dir/tests" -mindepth 1 -maxdepth 1 -not -name '.*' -type d -printf '%f\n' | sort)"

errors=0
report="${results_dir_name}/report.txt"

echo -n "Tests ran on: " >> $report
date >> $report
echo >> $report

for task in $tasks; do
	results="${results_dir_name}/$task.txt"

	echo -n "Tests ran on: " >> $results
	date >> $results
	echo >> $results

	correct_tests=0
	echo "Compiler output:" >> $results
	g++ fn*_d1_${task}.cpp -o "$task.out" -std=c++14 -Wpedantic &>> $results

	if [[ $? -eq 0 ]]; then
		echo >> $results
		echo "Compilation OK." >> $results
		echo >> $results
		echo >> $results

		tests_count=$(($(find "$tests_dir/tests/$task" | wc -l) / 2))

		for test in $(seq 1 $tests_count); do
			temp_file="$(mktemp)"
			timeout $timeout "./$task.out" < "$tests_dir/tests/$task/${test}-in" &> "$temp_file"

			if diff -Z "$temp_file" "$tests_dir/tests/$task/${test}-out" > /dev/null; then
				echo "Test \"${test}\": OK" >> $results
				correct_tests=$((correct_tests+1))
			else
				echo "Test \"${test}\": Failed" >> $results

				echo "Input:" >> $results
				cat "$tests_dir/tests/$task/${test}-in" >> $results
				echo >> $results

				echo "Expected:" >> $results
				cat "$tests_dir/tests/$task/${test}-out" >> $results
				echo >> $results

				echo "Actual:" >> $results
				head -c 1000 "$temp_file" >> $results
				echo >> $results

				errors=$((errors+1))
			fi

			echo "____________________" >> $results
			echo >> $results
		done

		percentage="$(awk -v correct=$correct_tests -v total=$tests_count 'BEGIN{printf("%.2f", correct * 100 / total)}')"
		points="$(awk -v cent=$percentage 'BEGIN{printf("%.1f", cent / 100 * 2.5)}')"

		echo "Grade: ${correct_tests}/${tests_count}, ${percentage}%, $points pts." >> $results
		echo "Task ${task}: ${correct_tests}/${tests_count}, ${percentage}%, $points pts." >> $report
	else
		errors=$((errors+1))

		echo >> $results
		echo "Compilation failed. Skipping tests." >> $results
		echo "Task ${task}: Does not compile" >> $report
	fi
done

tail -n +3 $report > $GITHUB_STEP_SUMMARY
echo >> $GITHUB_STEP_SUMMARY
echo 'Download "results" above to see the full test results' >> $GITHUB_STEP_SUMMARY

echo
echo

if [[ $errors -eq 0 ]]; then
    echo "🎉 All tests passed! Congratulations!"
    echo
    echo
fi

echo "Check the Summary tab on the left to download the test results."
echo
echo
echo

exit $errors
