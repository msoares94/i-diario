require 'rails_helper'

RSpec.describe Api::ClassroomAttendanceService do
  Timecop.travel(Time.zone.local(2024, 4, 1, 0, 0, 0))
  let(:classroom) { create(:classroom, id: 1, year: '2024', api_code: "01") }
  let(:school_calendar) {
    create(
      :school_calendar,
      year: '2024',
      unity_id: classroom.unity_id
    )
  }
  let!(:school_calendar_step) {
    create(
      :school_calendar_step,
      school_calendar: school_calendar,
      step_number: 1,
      start_at: '2024-02-02',
      end_at: '2024-12-12'
    )
  }
  let(:start_at) { '2024-02-02'}
  let(:end_at) { '2024-12-12'}
  let(:year) { '2024'}
  let(:params_classrooms) do
    {
      "0" => classroom.api_code
    }
  end
  let(:classrooms_grades) { create(:classrooms_grade, classroom: classroom) }
  let(:student_enrollment_classroom) { create(
      :student_enrollment_classroom,
      classrooms_grade: classrooms_grades,
      joined_at: '2024-03-28'
    )
  }
  let(:student_enrollment) { student_enrollment_classroom.student_enrollment }
  let(:student) { student_enrollment.student }
  let!(:daily_frequency) { create(:daily_frequency,classroom: classroom, frequency_date: '2024-04-01') }
  let!(:daily_frequency_student) {
    create(
      :daily_frequency_student,
      student: student,
      present: true,
      daily_frequency: daily_frequency
    )
  }

  before do
    UnitySchoolDay.create!(unity: classroom.unity, school_day: '2024-04-01')
    UnitySchoolDay.create!(unity: classroom.unity, school_day: '2024-03-29')
    UnitySchoolDay.create!(unity: classroom.unity, school_day: '2024-03-28')
  end

  context 'when params are correct' do
    subject(:service) do
      Api::ClassroomAttendanceService.call(params_classrooms, start_at, end_at, year)
    end

    let(:daily_frequency_two) { create(:daily_frequency, classroom: classroom, frequency_date: '2024-03-29') }

    it 'returns correct classroom, attendance and enrollments data when valid params' do
      expect(service.first[:classroom_name]).to include(classroom.description)
      expect(service.first[:grades]).to include(
        {
          id: classrooms_grades.grade.api_code,
          name: classrooms_grades.grade.description,
          course_id: classrooms_grades.grade.course.api_code,
          course_name: classrooms_grades.grade.course.description
        })
      expect(service.first[:attendance_and_enrollments]).to include(
        "2024-04-01" => {
          frequencies: 1,
          enrollments: 1
        }
      )
    end

    it 'returns nil when the student_enrollment_classroom has discarded_at' do
      student_enrollment_classroom.update(discarded_at: '2024-03-29')

      expect(service.first[:attendance_and_enrollments]).to be_nil
    end

    it 'returns 100% attendance and all students enrolled' do
      daily_frequency_student= create(:daily_frequency_student, student: student, present: true, daily_frequency: daily_frequency_two)

      expect(service.first[:attendance_and_enrollments]).to include(
        {
          "2024-03-29" => {
            frequencies: 1,
            enrollments: 1
          },
          "2024-04-01" => {
            frequencies: 1,
            enrollments: 1
          }
        }
      )
    end

    it 'returns 50% or 100% attendance for all students in the classroom' do
      student_enrollment_classroom_two = create(
        :student_enrollment_classroom,
        classrooms_grade: classrooms_grades,
        joined_at: '2024-03-29'
      )
      student_enrollment_two = student_enrollment_classroom_two.student_enrollment
      student_two = student_enrollment_two.student

      create(:daily_frequency_student, student: student_two, present: true, daily_frequency: daily_frequency)
      create(:daily_frequency_student, student: student_two, present: true, daily_frequency: daily_frequency_two)

      service = Api::ClassroomAttendanceService.call(params_classrooms, start_at, end_at, year)

      expect(service.first[:attendance_and_enrollments]).to include(
        {
          "2024-03-28" => {
            frequencies: 0,
            enrollments: 1
          },
          "2024-03-29" => {
            frequencies: 1,
            enrollments: 2
          },
          "2024-04-01" => {
            frequencies: 2,
            enrollments: 2
          }
        }
      )
    end

    it 'returns only the attendance of students with active enrollment on the date' do
      # Enturma alunos
      student_enrollment_classroom_three = create(
        :student_enrollment_classroom,
        classrooms_grade: classrooms_grades,
        joined_at: '2024-03-28'
      )
      student_enrollment_three = student_enrollment_classroom_three.student_enrollment
      student_three = student_enrollment_three.student
      student_enrollment_classroom_two = create(
        :student_enrollment_classroom,
        classrooms_grade: classrooms_grades
      )
      student_enrollment_two = student_enrollment_classroom_two.student_enrollment
      student_two = student_enrollment_two.student
      # Lança a frequencia alunos para 01/04/2024
      create(:daily_frequency_student, student: student_two, present: true, daily_frequency: daily_frequency)
      create(:daily_frequency_student, student: student_three, present: true, daily_frequency: daily_frequency)
      # Lança a frequencia alunos para 29/03/2024
      create(:daily_frequency_student, student: student_two, present: true, daily_frequency: daily_frequency_two)
      create(:daily_frequency_student, student: student_three, present: true, daily_frequency: daily_frequency_two)

      # Mudar a enturmacao, Insere saida do aluno retroativa ==> cenário problematico
      student_enrollment_classroom_two.update(left_at: '2024-03-29')

      service = Api::ClassroomAttendanceService.call(params_classrooms, start_at, end_at, year)

      expect(service.first[:attendance_and_enrollments]).to include(
        {
          "2024-04-01" => {
            frequencies: 2,
            enrollments: 2
          },
          "2024-03-29" => {
            frequencies: 2,
            enrollments: 3
          },
          "2024-03-28" => {
            frequencies: 0,
            enrollments: 3
          }
        }
      )
    end

    it 'returns attendance only for students with active enrollment on the date' do
      # Enturma 2 alunos, entrando dia 28/03/2024
      student_enrollment_classroom_three = create(
        :student_enrollment_classroom,
        classrooms_grade: classrooms_grades,
        joined_at: '2024-03-28'
      )
      student_enrollment_three = student_enrollment_classroom_three.student_enrollment
      student_three = student_enrollment_three.student
      student_enrollment_classroom_two = create(
        :student_enrollment_classroom,
        classrooms_grade: classrooms_grades,
        joined_at: '2024-03-28'
      )
      student_enrollment_two = student_enrollment_classroom_two.student_enrollment
      student_two = student_enrollment_two.student

      # Lança a frequencia alunos para 01/04/2024
      create(:daily_frequency_student, student: student_two, present: true, daily_frequency: daily_frequency)
      create(:daily_frequency_student, student: student_three, present: true, daily_frequency: daily_frequency)

      # Lança a frequencia alunos para 29/03/2024
      daily_frequency_two = create(:daily_frequency, classroom: classroom, frequency_date: '2024-03-29')
      create(:daily_frequency_student, student: student, present: true, daily_frequency: daily_frequency_two)
      create(:daily_frequency_student, student: student_two, present: true, daily_frequency: daily_frequency_two)
      create(:daily_frequency_student, student: student_three, present: true, daily_frequency: daily_frequency_two)

      # Descartar a enturmacao
      student_enrollment_classroom_three.update(discarded_at: '2024-03-29')

      expect(service.first[:attendance_and_enrollments]).to include(
        {
          "2024-04-01" => {
            frequencies: 2,
            enrollments: 2
          },
          "2024-03-29" => {
            frequencies: 2,
            enrollments: 2
          },
          "2024-03-28" => {
            frequencies: 0,
            enrollments: 2
          }
        }
      )
    end
  end

  context 'when there are more than one classroom' do
    # Cria +1 turma
    let(:classroom_two) { create(:classroom, id: 2, year: '2024', api_code: '02', unity: classroom.unity) }
    let(:classrooms_grades_two) { create(:classrooms_grade, classroom: classroom_two) }
    let(:params_classrooms_two) do
      {
        "0" => classroom.api_code,
        "1" => classroom_two.api_code
      }
    end
    # Enturma 1 aluno, entrando dia 28/03/2024
    let!(:student_enrollment_classroom_two) { create(
        :student_enrollment_classroom,
        classrooms_grade: classrooms_grades,
        joined_at: '2024-03-28'
      )
    }
    let!(:student_enrollment_two) { student_enrollment_classroom_two.student_enrollment }
    let!(:student_two) { student_enrollment_two.student }

    it '' do
      # Lança a frequencia alunos para 01/04/2024
      create(:daily_frequency_student, student: student_two, present: true, daily_frequency: daily_frequency)

      # Lança a frequencia alunos para 29/03/2024
      daily_frequency_two = create(:daily_frequency, classroom: classroom, frequency_date: '2024-03-29')
      create(:daily_frequency_student, student: student, present: true, daily_frequency: daily_frequency_two)
      create(:daily_frequency_student, student: student_two, present: true, daily_frequency: daily_frequency_two)

      # Mudar a enturmacao
      student_enrollment_classroom_two.update(left_at: '2024-03-29')

      # Re-Enturmei o aluno na nova a turma
      new_student_enrollment_classroom = create(
        :student_enrollment_classroom,
        classrooms_grade: classrooms_grades_two,
        student_enrollment: student_enrollment_two,
        joined_at: '2024-03-28'
      )

      # Lança a frequencia alunos para 01/04/2024 para outra turma
      daily_frequency_two = create(:daily_frequency, classroom: classroom_two, frequency_date: '2024-04-01')
      create(:daily_frequency_student, student: student_two, present: true, daily_frequency: daily_frequency_two)
      binding.pry
      service = Api::ClassroomAttendanceService.call(params_classrooms_two, start_at, end_at, year)
      expect(service.last[:classroom_id]).to include(classroom_two.api_code)
      expect(service.last[:attendance_and_enrollments]).to include(
        {
          "2024-04-01" => {
            frequencies: 1,
            enrollments: 1
          },
          "2024-03-29" => {
            frequencies: 0,
            enrollments: 1
          },
          "2024-03-28" => {
            frequencies: 0,
            enrollments: 1
          }
        }
      )
      expect(service.first[:classroom_id]).to include(classroom.api_code)
      expect(service.first[:attendance_and_enrollments]).to include(
        {
          "2024-04-01" => {
            frequencies: 2,
            enrollments: 1
          },
          "2024-03-29" => {
            frequencies: 2,
            enrollments: 2
          },
          "2024-03-28" => {
            frequencies: 0,
            enrollments: 2
          }
        }
      )
    end

    it '' do
      # Lança a frequencia alunos para 01/04/2024
      create(:daily_frequency_student, student: student_two, present: true, daily_frequency: daily_frequency)

      # Lança a frequencia alunos para 29/03/2024
      daily_frequency_two = create(:daily_frequency, classroom: classroom, frequency_date: '2024-03-29')
      create(:daily_frequency_student, student: student, present: true, daily_frequency: daily_frequency_two)
      create(:daily_frequency_student, student: student_two, present: true, daily_frequency: daily_frequency_two)

      # Mudar a enturmacao
      student_enrollment_classroom_two.update(discarded_at: '2024-03-29')

      # Re-Enturmei o aluno na nova a turma
      new_student_enrollment_classroom = create(
        :student_enrollment_classroom,
        classrooms_grade: classrooms_grades_two,
        student_enrollment: student_enrollment_two,
        joined_at: '2024-03-28'
      )

      # Lança a frequencia alunos para 01/04/2024 para outra turma
      daily_frequency_two = create(:daily_frequency, classroom: classroom_two, frequency_date: '2024-04-01')
      create(:daily_frequency_student, student: student_two, present: true, daily_frequency: daily_frequency_two)

      service = Api::ClassroomAttendanceService.call(params_classrooms_two, start_at, end_at, year)

      expect(service.last[:classroom_id]).to include(classroom_two.api_code)
      expect(service.last[:attendance_and_enrollments]).to include(
        {
          "2024-04-01" => {
            frequencies: 1,
            enrollments: 1
          },
          "2024-03-29" => {
            frequencies: 0,
            enrollments: 1
          },
          "2024-03-28" => {
            frequencies: 0,
            enrollments: 1
          }
        }
      )
      expect(service.first[:classroom_id]).to include(classroom.api_code)
      expect(service.first[:attendance_and_enrollments]).to include(
        {
          "2024-04-01" => {
            frequencies: 2,
            enrollments: 1
          },
          "2024-03-29" => {
            frequencies: 2,
            enrollments: 1
          },
          "2024-03-28" => {
            frequencies: 0,
            enrollments: 1
          }
        }
      )
    end
  end
end
