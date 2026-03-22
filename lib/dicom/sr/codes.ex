defmodule Dicom.SR.Codes do
  @moduledoc """
  Common normative codes used by the current SR helpers and templates.
  """

  alias Dicom.SR.Code

  @spec imaging_measurement_report() :: Code.t()
  def imaging_measurement_report,
    do: Code.new("126000", "DCM", "Imaging Measurement Report")

  @spec imaging_measurements() :: Code.t()
  def imaging_measurements, do: Code.new("126010", "DCM", "Imaging Measurements")

  @spec measurement_group() :: Code.t()
  def measurement_group, do: Code.new("125007", "DCM", "Measurement Group")

  @spec tracking_identifier() :: Code.t()
  def tracking_identifier, do: Code.new("112039", "DCM", "Tracking Identifier")

  @spec tracking_unique_identifier() :: Code.t()
  def tracking_unique_identifier, do: Code.new("112040", "DCM", "Tracking Unique Identifier")

  @spec finding() :: Code.t()
  def finding, do: Code.new("121071", "DCM", "Finding")

  @spec finding_site() :: Code.t()
  def finding_site, do: Code.new("363698007", "SCT", "Finding Site")

  @spec impression() :: Code.t()
  def impression, do: Code.new("121073", "DCM", "Impression")

  @spec recommendation() :: Code.t()
  def recommendation, do: Code.new("121075", "DCM", "Recommendation")

  @spec procedure_reported() :: Code.t()
  def procedure_reported, do: Code.new("121058", "DCM", "Procedure reported")

  @spec language_of_content_item_and_descendants() :: Code.t()
  def language_of_content_item_and_descendants,
    do: Code.new("121049", "DCM", "Language of Content Item and Descendants")

  @spec observer_type() :: Code.t()
  def observer_type, do: Code.new("121005", "DCM", "Observer Type")

  @spec person() :: Code.t()
  def person, do: Code.new("121006", "DCM", "Person")

  @spec device() :: Code.t()
  def device, do: Code.new("121007", "DCM", "Device")

  @spec device_observer_uid() :: Code.t()
  def device_observer_uid, do: Code.new("121012", "DCM", "Device Observer UID")

  @spec device_observer_name() :: Code.t()
  def device_observer_name, do: Code.new("121013", "DCM", "Device Observer Name")

  @spec device_observer_manufacturer() :: Code.t()
  def device_observer_manufacturer,
    do: Code.new("121014", "DCM", "Device Observer Manufacturer")

  @spec device_observer_model_name() :: Code.t()
  def device_observer_model_name, do: Code.new("121015", "DCM", "Device Observer Model Name")

  @spec device_observer_serial_number() :: Code.t()
  def device_observer_serial_number,
    do: Code.new("121016", "DCM", "Device Observer Serial Number")

  @spec person_observer_name() :: Code.t()
  def person_observer_name, do: Code.new("121008", "DCM", "Person Observer Name")

  @spec source() :: Code.t()
  def source, do: Code.new("260753009", "SCT", "Source")

  @spec image_library() :: Code.t()
  def image_library, do: Code.new("111028", "DCM", "Image Library")

  @spec image_region() :: Code.t()
  def image_region, do: Code.new("111030", "DCM", "Image Region")

  @spec original_source() :: Code.t()
  def original_source, do: Code.new("111040", "DCM", "Original Source")

  @spec procedure_description() :: Code.t()
  def procedure_description, do: Code.new("121065", "DCM", "Procedure Description")

  @spec activity_session() :: Code.t()
  def activity_session, do: Code.new("C67447", "NCIt", "Activity Session")

  @spec finding_category() :: Code.t()
  def finding_category, do: Code.new("276214006", "SCT", "Finding category")

  @spec ecg_report() :: Code.t()
  def ecg_report, do: Code.new("28010-7", "LN", "ECG Report")

  @spec ecg_global_measurements() :: Code.t()
  def ecg_global_measurements, do: Code.new("122158", "DCM", "ECG Global Measurements")

  @spec ecg_lead_measurements() :: Code.t()
  def ecg_lead_measurements, do: Code.new("122159", "DCM", "ECG Lead Measurements")

  @spec stress_testing_report() :: Code.t()
  def stress_testing_report, do: Code.new("18752-6", "LN", "Stress Testing Report")

  # Key Object Selection codes (TID 2000)

  @spec key_object_selection() :: Code.t()
  def key_object_selection, do: Code.new("113000", "DCM", "Of Interest")

  @spec key_object_description() :: Code.t()
  def key_object_description, do: Code.new("113012", "DCM", "Key Object Description")

  @spec rejected_for_quality_reasons() :: Code.t()
  def rejected_for_quality_reasons,
    do: Code.new("113001", "DCM", "Rejected for Quality Reasons")

  @spec best_in_set() :: Code.t()
  def best_in_set, do: Code.new("113018", "DCM", "Best In Set")

  # Waveform Annotation codes (TID 3750)

  @spec waveform_annotation() :: Code.t()
  def waveform_annotation, do: Code.new("122172", "DCM", "Waveform Annotation")

  @spec comment() :: Code.t()
  def comment, do: Code.new("121106", "DCM", "Comment")

  @spec waveform_reference() :: Code.t()
  def waveform_reference, do: Code.new("122175", "DCM", "Waveform Reference")

  @spec abdominal_circumference() :: Code.t()
  def abdominal_circumference,
    do: Code.new("11979-2", "LN", "Abdominal circumference")

  @spec access_site() :: Code.t()
  def access_site, do: Code.new("111027", "DCM", "Access Site")

  @spec accumulated_dose() :: Code.t()
  def accumulated_dose, do: Code.new("113702", "DCM", "Accumulated Dose Data")

  @spec accumulated_xray_dose() :: Code.t()
  def accumulated_xray_dose,
    do: Code.new("113702", "DCM", "Accumulated X-Ray Dose Data")

  @spec acquisition_dose_area_product() :: Code.t()
  def acquisition_dose_area_product,
    do: Code.new("113727", "DCM", "Acquisition Dose Area Product Total")

  @spec actual_dose() :: Code.t()
  def actual_dose, do: Code.new("113521", "DCM", "Actual Dose")

  @spec actual_volume() :: Code.t()
  def actual_volume, do: Code.new("113522", "DCM", "Actual Volume")

  @spec add_power() :: Code.t()
  def add_power, do: Code.new("251718005", "SCT", "Addition")

  @spec adhoc_measurements() :: Code.t()
  def adhoc_measurements, do: Code.new("125303", "DCM", "Adhoc Measurements")

  @spec administered_activity() :: Code.t()
  def administered_activity, do: Code.new("113508", "DCM", "Administered Activity")

  @spec administration_datetime() :: Code.t()
  def administration_datetime, do: Code.new("113507", "DCM", "DateTime Started")

  @spec adverse_event() :: Code.t()
  def adverse_event, do: Code.new("121071", "DCM", "Finding")

  @spec agent_concentration() :: Code.t()
  def agent_concentration, do: Code.new("118555000", "SCT", "Substance concentration")

  @spec algorithm_name() :: Code.t()
  def algorithm_name, do: Code.new("111001", "DCM", "Algorithm Name")

  @spec algorithm_version() :: Code.t()
  def algorithm_version, do: Code.new("111003", "DCM", "Algorithm Version")

  @spec amniotic_fluid_index() :: Code.t()
  def amniotic_fluid_index, do: Code.new("11818-2", "LN", "Amniotic fluid index")

  @spec amniotic_sac() :: Code.t()
  def amniotic_sac, do: Code.new("121072", "DCM", "Amniotic Sac")

  @spec anesthesia() :: Code.t()
  def anesthesia, do: Code.new("128130", "DCM", "Anesthesia")

  @spec anesthesia_agent() :: Code.t()
  def anesthesia_agent, do: Code.new("128131", "DCM", "Anesthesia Agent")

  @spec animal_housing() :: Code.t()
  def animal_housing, do: Code.new("128121", "DCM", "Animal Housing")

  @spec annular_measurements() :: Code.t()
  def annular_measurements, do: Code.new("125321", "DCM", "Annular Measurements")

  @spec anterior_fibromuscular_stroma() :: Code.t()
  def anterior_fibromuscular_stroma,
    do: Code.new("253718006", "SCT", "Anterior fibromuscular stroma of prostate")

  @spec aortic_valve() :: Code.t()
  def aortic_valve, do: Code.new("34202007", "SCT", "Aortic valve structure")

  @spec architectural_distortion() :: Code.t()
  def architectural_distortion,
    do: Code.new("129770000", "SCT", "Architectural distortion of breast")

  @spec asymmetry() :: Code.t()
  def asymmetry, do: Code.new("129769005", "SCT", "Asymmetry of breast tissue")

  @spec attenuation_coefficient() :: Code.t()
  def attenuation_coefficient, do: Code.new("131190", "DCM", "Attenuation Coefficient")

  @spec axial_acquisition() :: Code.t()
  def axial_acquisition, do: Code.new("113804", "DCM", "Sequenced Acquisition")

  @spec biosafety_conditions() :: Code.t()
  def biosafety_conditions, do: Code.new("128110", "DCM", "Biosafety Conditions")

  @spec biosafety_level() :: Code.t()
  def biosafety_level, do: Code.new("128111", "DCM", "Biosafety Level")

  @spec biparietal_diameter() :: Code.t()
  def biparietal_diameter, do: Code.new("11820-8", "LN", "Biparietal diameter")

  # BI-RADS Assessment Categories (CID 6027)

  @spec birads_category_0() :: Code.t()
  def birads_category_0,
    do: Code.new("111170", "DCM", "Incomplete - Need Additional Imaging Evaluation")

  @spec birads_category_1() :: Code.t()
  def birads_category_1, do: Code.new("111171", "DCM", "Negative")

  @spec birads_category_2() :: Code.t()
  def birads_category_2, do: Code.new("111172", "DCM", "Benign")

  @spec birads_category_3() :: Code.t()
  def birads_category_3, do: Code.new("111173", "DCM", "Probably Benign")

  @spec birads_category_4() :: Code.t()
  def birads_category_4, do: Code.new("111174", "DCM", "Suspicious")

  @spec birads_category_5() :: Code.t()
  def birads_category_5,
    do: Code.new("111175", "DCM", "Highly Suggestive of Malignancy")

  @spec birads_category_6() :: Code.t()
  def birads_category_6,
    do: Code.new("111176", "DCM", "Known Biopsy Proven Malignancy")

  @spec blood_velocity() :: Code.t()
  def blood_velocity, do: Code.new("110852", "DCM", "Blood Velocity")

  @spec body_height() :: Code.t()
  def body_height, do: Code.new("50373000", "SCT", "Body height measure")

  # Phantom type value codes

  @spec body_phantom() :: Code.t()
  def body_phantom, do: Code.new("113691", "DCM", "IEC Body Dosimetry Phantom")

  @spec body_surface_area() :: Code.t()
  def body_surface_area, do: Code.new("301898006", "SCT", "Body surface area")

  @spec body_weight() :: Code.t()
  def body_weight, do: Code.new("27113001", "SCT", "Body weight")

  @spec breast_composition() :: Code.t()
  def breast_composition, do: Code.new("111031", "DCM", "Breast Composition")

  # Breast Imaging Report codes (TID 4200)

  @spec breast_imaging_report() :: Code.t()
  def breast_imaging_report, do: Code.new("111036", "DCM", "Breast Imaging Report")

  @spec cad_processing_and_findings_summary() :: Code.t()
  def cad_processing_and_findings_summary,
    do: Code.new("111017", "DCM", "CAD Processing and Findings Summary")

  @spec calcification() :: Code.t()
  def calcification, do: Code.new("129748003", "SCT", "Calcification of breast")

  @spec calcification_cluster() :: Code.t()
  def calcification_cluster, do: Code.new("129750", "DCM", "Calcification Cluster")

  @spec calcium_mass_score() :: Code.t()
  def calcium_mass_score, do: Code.new("112229", "DCM", "Mass Score")

  @spec calcium_score() :: Code.t()
  def calcium_score, do: Code.new("112227", "DCM", "Calcium Score")

  @spec calcium_scoring_section() :: Code.t()
  def calcium_scoring_section, do: Code.new("113691", "DCM", "Calcium Scoring")

  @spec calcium_volume_score() :: Code.t()
  def calcium_volume_score, do: Code.new("112228", "DCM", "Volume Score")

  # Cardiac Catheterization Report codes (TID 3800)

  @spec cardiac_catheterization_report() :: Code.t()
  def cardiac_catheterization_report,
    do: Code.new("18745-0", "LN", "Cardiac catheterization study")

  @spec cardiac_measurements() :: Code.t()
  def cardiac_measurements, do: Code.new("125201", "DCM", "Cardiac Measurements")

  @spec cardiac_output() :: Code.t()
  def cardiac_output, do: Code.new("8741-1", "LN", "Cardiac output")

  # CT/MR Cardiovascular Analysis Report codes (TID 3900)

  @spec cardiovascular_analysis_report() :: Code.t()
  def cardiovascular_analysis_report,
    do: Code.new("18745-0", "LN", "Cardiac catheterization study")

  @spec catheter_type() :: Code.t()
  def catheter_type, do: Code.new("111026", "DCM", "Catheter Type")

  @spec central_subfield_thickness() :: Code.t()
  def central_subfield_thickness,
    do: Code.new("410669006", "SCT", "Central subfield retinal thickness")

  @spec central_zone() :: Code.t()
  def central_zone, do: Code.new("279710000", "SCT", "Central zone of prostate")

  @spec cervical_length() :: Code.t()
  def cervical_length, do: Code.new("11957-8", "LN", "Cervical length")

  @spec chest_cad_report() :: Code.t()
  def chest_cad_report, do: Code.new("111036", "DCM", "Chest CAD Report")

  @spec clinical_information() :: Code.t()
  def clinical_information, do: Code.new("55752-0", "LN", "Clinical Information")

  # TID 4120 Colon CAD codes

  @spec colon_cad_report() :: Code.t()
  def colon_cad_report, do: Code.new("111060", "DCM", "Colon CAD Report")

  @spec colonic_segment() :: Code.t()
  def colonic_segment, do: Code.new("T-59300", "SRT", "Colon")

  @spec composite_feature() :: Code.t()
  def composite_feature, do: Code.new("111058", "DCM", "Composite Feature")

  @spec conclusion() :: Code.t()
  def conclusion, do: Code.new("121077", "DCM", "Conclusion")

  @spec conclusions() :: Code.t()
  def conclusions, do: Code.new("121076", "DCM", "Conclusions")

  @spec consumable() :: Code.t()
  def consumable, do: Code.new("113541", "DCM", "Consumable")

  @spec consumable_used() :: Code.t()
  def consumable_used, do: Code.new("121170", "DCM", "Consumable Used")

  @spec coronary_findings() :: Code.t()
  def coronary_findings, do: Code.new("122153", "DCM", "Coronary Findings")

  @spec coronary_stenosis() :: Code.t()
  def coronary_stenosis, do: Code.new("36228007", "SCT", "Coronary artery stenosis")

  @spec ct_accumulated_dose_data() :: Code.t()
  def ct_accumulated_dose_data,
    do: Code.new("113811", "DCM", "CT Accumulated Dose Data")

  @spec ct_acquisition_type() :: Code.t()
  def ct_acquisition_type, do: Code.new("113820", "DCM", "CT Acquisition Type")

  @spec ct_dose_length_product_total() :: Code.t()
  def ct_dose_length_product_total,
    do: Code.new("113813", "DCM", "CT Dose Length Product Total")

  @spec ct_irradiation_event_data() :: Code.t()
  def ct_irradiation_event_data,
    do: Code.new("113819", "DCM", "CT Irradiation Event Data")

  @spec ct_radiation_dose_report() :: Code.t()
  def ct_radiation_dose_report,
    do: Code.new("113811", "DCM", "CT Radiation Dose Report")

  @spec ctdi_vol() :: Code.t()
  def ctdi_vol, do: Code.new("113830", "DCM", "CTDIvol")

  @spec cubic_millimeter() :: Code.t()
  def cubic_millimeter, do: Code.new("mm3", "UCUM", "cubic millimeter")

  @spec current_procedure_descriptions() :: Code.t()
  def current_procedure_descriptions,
    do: Code.new("121064", "DCM", "Current Procedure Descriptions")

  @spec cylinder_axis() :: Code.t()
  def cylinder_axis, do: Code.new("251799001", "SCT", "Cylinder axis")

  @spec cylinder_power() :: Code.t()
  def cylinder_power, do: Code.new("251797004", "SCT", "Cylinder power")

  @spec datetime_started() :: Code.t()
  def datetime_started, do: Code.new("113809", "DCM", "Start of X-Ray Irradiation")

  @spec dce_curve_type() :: Code.t()
  def dce_curve_type, do: Code.new("126422", "DCM", "DCE Curve Type")

  @spec degree() :: Code.t()
  def degree, do: Code.new("deg", "UCUM", "degree")

  @spec derived_hemodynamic_measurements() :: Code.t()
  def derived_hemodynamic_measurements,
    do: Code.new("122102", "DCM", "Derived Hemodynamic Measurements")

  @spec detection_confidence() :: Code.t()
  def detection_confidence, do: Code.new("111058", "DCM", "Detection confidence")

  @spec device_measurements() :: Code.t()
  def device_measurements, do: Code.new("125322", "DCM", "Device Measurements")

  @spec diastolic_blood_pressure() :: Code.t()
  def diastolic_blood_pressure, do: Code.new("8462-4", "LN", "Diastolic blood pressure")

  @spec diopter() :: Code.t()
  def diopter, do: Code.new("dpt", "UCUM", "diopter")

  @spec discharge_summary() :: Code.t()
  def discharge_summary, do: Code.new("121077", "DCM", "Discharge Summary")

  @spec dlp() :: Code.t()
  def dlp, do: Code.new("113838", "DCM", "DLP")

  @spec dose_area_product() :: Code.t()
  def dose_area_product, do: Code.new("113725", "DCM", "Dose Area Product")

  @spec dose_estimate() :: Code.t()
  def dose_estimate, do: Code.new("113813", "DCM", "Dose Estimate")

  @spec dose_estimate_methodology() :: Code.t()
  def dose_estimate_methodology,
    do: Code.new("113835", "DCM", "Dose Estimation Methodology")

  @spec dose_estimate_type() :: Code.t()
  def dose_estimate_type, do: Code.new("113813", "DCM", "Dose Estimate")

  @spec dose_estimation_parameters() :: Code.t()
  def dose_estimation_parameters, do: Code.new("113834", "DCM", "Dose Estimation Parameters")

  @spec dose_rp() :: Code.t()
  def dose_rp, do: Code.new("113738", "DCM", "Dose (RP)")

  @spec drug_administered() :: Code.t()
  def drug_administered, do: Code.new("121150", "DCM", "Drug Administered")

  @spec dwi_signal_score() :: Code.t()
  def dwi_signal_score, do: Code.new("126421", "DCM", "DWI Signal Score")

  # Echocardiography Report codes (TID 5200)

  @spec echocardiography_report() :: Code.t()
  def echocardiography_report,
    do: Code.new("59282-4", "LN", "Stress echocardiography study report")

  # Radiation Dose common codes

  @spec effective_dose() :: Code.t()
  def effective_dose, do: Code.new("113839", "DCM", "Effective Dose")

  @spec ejection_fraction() :: Code.t()
  def ejection_fraction, do: Code.new("10230-1", "LN", "Ejection Fraction")

  @spec end_datetime() :: Code.t()
  def end_datetime, do: Code.new("113510", "DCM", "End DateTime")

  @spec end_diastolic_velocity() :: Code.t()
  def end_diastolic_velocity,
    do: Code.new("11653-3", "LN", "End diastolic velocity")

  @spec end_diastolic_volume() :: Code.t()
  def end_diastolic_volume, do: Code.new("10231-9", "LN", "End Diastolic Volume")

  @spec end_systolic_volume() :: Code.t()
  def end_systolic_volume, do: Code.new("10232-7", "LN", "End Systolic Volume")

  # TID 10040 Enhanced X-Ray Radiation Dose Report codes

  @spec enhanced_xray_dose_report() :: Code.t()
  def enhanced_xray_dose_report,
    do: Code.new("113710", "DCM", "X-Ray Radiation Dose Report")

  @spec estimated_date_of_delivery() :: Code.t()
  def estimated_date_of_delivery,
    do: Code.new("11778-8", "LN", "Estimated date of delivery")

  @spec estimated_fetal_weight() :: Code.t()
  def estimated_fetal_weight, do: Code.new("11727-5", "LN", "Estimated fetal weight")

  @spec exposure_time() :: Code.t()
  def exposure_time, do: Code.new("113735", "DCM", "Exposure Time")

  @spec extraprostatic_extension() :: Code.t()
  def extraprostatic_extension, do: Code.new("126431", "DCM", "Extraprostatic Extension")

  @spec extraprostatic_finding() :: Code.t()
  def extraprostatic_finding, do: Code.new("126404", "DCM", "Extra-prostatic Finding")

  @spec family_history() :: Code.t()
  def family_history, do: Code.new("10157-6", "LN", "Family history")

  @spec femur_length() :: Code.t()
  def femur_length, do: Code.new("11963-6", "LN", "Femur length")

  @spec fetal_biometry() :: Code.t()
  def fetal_biometry, do: Code.new("121069", "DCM", "Fetal Biometry")

  @spec fetal_heart_activity() :: Code.t()
  def fetal_heart_activity, do: Code.new("11948-7", "LN", "Fetal heart activity")

  @spec fetal_number() :: Code.t()
  def fetal_number, do: Code.new("11878-6", "LN", "Fetal number")

  @spec fetal_presentation() :: Code.t()
  def fetal_presentation, do: Code.new("11876-0", "LN", "Fetal presentation")

  @spec fetus_summary() :: Code.t()
  def fetus_summary, do: Code.new("121070", "DCM", "Fetus Summary")

  @spec findings() :: Code.t()
  def findings, do: Code.new("121070", "DCM", "Findings")

  @spec findings_summary() :: Code.t()
  def findings_summary, do: Code.new("111035", "DCM", "Findings")

  @spec flow_direction() :: Code.t()
  def flow_direction,
    do: Code.new("399226006", "SCT", "Blood flow direction")

  @spec flow_rate() :: Code.t()
  def flow_rate, do: Code.new("424254007", "SCT", "Flow Rate")

  @spec fluoro_dose_area_product() :: Code.t()
  def fluoro_dose_area_product,
    do: Code.new("113726", "DCM", "Fluoro Dose Area Product Total")

  @spec fractional_shortening() :: Code.t()
  def fractional_shortening,
    do: Code.new("18043-3", "LN", "Left ventricular Fractional shortening")

  # General Ultrasound Report codes (TID 12000)

  @spec general_ultrasound_report() :: Code.t()
  def general_ultrasound_report,
    do: Code.new("126060", "DCM", "General Ultrasound Report")

  @spec gestational_age() :: Code.t()
  def gestational_age, do: Code.new("11884-4", "LN", "Gestational age")

  @spec graft_section() :: Code.t()
  def graft_section,
    do: Code.new("12101003", "SCT", "Graft")

  @spec gravidity() :: Code.t()
  def gravidity, do: Code.new("11996-6", "LN", "Gravidity")

  # ETDRS 9-sector grid locations

  @spec grid_center() :: Code.t()
  def grid_center, do: Code.new("110860", "DCM", "Center")

  @spec grid_inner_inferior() :: Code.t()
  def grid_inner_inferior, do: Code.new("110863", "DCM", "Inner Inferior")

  @spec grid_inner_nasal() :: Code.t()
  def grid_inner_nasal, do: Code.new("110862", "DCM", "Inner Nasal")

  @spec grid_inner_superior() :: Code.t()
  def grid_inner_superior, do: Code.new("110861", "DCM", "Inner Superior")

  @spec grid_inner_temporal() :: Code.t()
  def grid_inner_temporal, do: Code.new("110864", "DCM", "Inner Temporal")

  @spec grid_outer_inferior() :: Code.t()
  def grid_outer_inferior, do: Code.new("110867", "DCM", "Outer Inferior")

  @spec grid_outer_nasal() :: Code.t()
  def grid_outer_nasal, do: Code.new("110866", "DCM", "Outer Nasal")

  @spec grid_outer_superior() :: Code.t()
  def grid_outer_superior, do: Code.new("110865", "DCM", "Outer Superior")

  @spec grid_outer_temporal() :: Code.t()
  def grid_outer_temporal, do: Code.new("110868", "DCM", "Outer Temporal")

  # Unit codes for radiation dose measurements

  @spec gy_cm2() :: Code.t()
  def gy_cm2, do: Code.new("Gy.m2", "UCUM", "Gy.m2")

  @spec head_circumference() :: Code.t()
  def head_circumference, do: Code.new("11984-2", "LN", "Head circumference")

  @spec head_phantom() :: Code.t()
  def head_phantom, do: Code.new("113690", "DCM", "IEC Head Dosimetry Phantom")

  @spec heart_rate() :: Code.t()
  def heart_rate, do: Code.new("8867-4", "LN", "Heart rate")

  # CT acquisition type value codes

  @spec helical_acquisition() :: Code.t()
  def helical_acquisition, do: Code.new("P5-08001", "SRT", "Spiral")

  @spec hemodynamic_measurements() :: Code.t()
  def hemodynamic_measurements, do: Code.new("122101", "DCM", "Hemodynamic Measurements")

  # Hemodynamic Report codes (TID 3500 / PS3.16)

  @spec hemodynamic_report() :: Code.t()
  def hemodynamic_report, do: Code.new("122100", "DCM", "Hemodynamic Report")

  @spec history() :: Code.t()
  def history, do: Code.new("121060", "DCM", "History")

  @spec housing_type() :: Code.t()
  def housing_type, do: Code.new("128122", "DCM", "Housing Type")

  @spec image_acquisition() :: Code.t()
  def image_acquisition, do: Code.new("121149", "DCM", "Image Acquisition")

  @spec imaging_agent() :: Code.t()
  def imaging_agent, do: Code.new("113500", "DCM", "Imaging Agent")

  # TID 2006 Imaging Report codes

  @spec imaging_report() :: Code.t()
  def imaging_report, do: Code.new("18748-4", "LN", "Diagnostic Imaging Report")

  @spec implant_template() :: Code.t()
  def implant_template, do: Code.new("122349", "DCM", "Implant Template")

  # TID 7000 Implantation Plan codes

  @spec implantation_plan() :: Code.t()
  def implantation_plan, do: Code.new("122361", "DCM", "Implantation Plan SR Document")

  @spec implantation_site() :: Code.t()
  def implantation_site, do: Code.new("111176", "DCM", "Implantation Site")

  @spec individual_impression_recommendation() :: Code.t()
  def individual_impression_recommendation,
    do: Code.new("111064", "DCM", "Individual Impression/Recommendation")

  @spec injection_site() :: Code.t()
  def injection_site, do: Code.new("246513007", "SCT", "Site of injection")

  @spec interpupillary_distance() :: Code.t()
  def interpupillary_distance, do: Code.new("251762001", "SCT", "Interpupillary distance")

  @spec interventricular_septum_thickness() :: Code.t()
  def interventricular_septum_thickness,
    do: Code.new("18154-8", "LN", "Interventricular septum thickness end diastole")

  @spec intravenous_route() :: Code.t()
  def intravenous_route, do: Code.new("47625008", "SCT", "Intravenous route")

  @spec irradiation_details() :: Code.t()
  def irradiation_details, do: Code.new("113724", "DCM", "Irradiation Event Data")

  @spec irradiation_event_summary() :: Code.t()
  def irradiation_event_summary, do: Code.new("113706", "DCM", "Irradiation Event")

  @spec irradiation_event_uid() :: Code.t()
  def irradiation_event_uid, do: Code.new("113769", "DCM", "Irradiation Event UID")

  @spec irradiation_event_xray_data() :: Code.t()
  def irradiation_event_xray_data,
    do: Code.new("113706", "DCM", "Irradiation Event X-Ray Data")

  # IVUS Report codes (TID 3250)

  @spec ivus_report() :: Code.t()
  def ivus_report, do: Code.new("125200", "DCM", "IVUS Report")

  @spec kidney_function() :: Code.t()
  def kidney_function,
    do: Code.new("80274001", "SCT", "Glomerular filtration rate")

  @spec kilovolt() :: Code.t()
  def kilovolt, do: Code.new("kV", "UCUM", "kV")

  @spec kvp() :: Code.t()
  def kvp, do: Code.new("113733", "DCM", "KVP")

  @spec last_menstrual_period() :: Code.t()
  def last_menstrual_period, do: Code.new("11955-2", "LN", "Last menstrual period")

  @spec laterality() :: Code.t()
  def laterality, do: Code.new("272741003", "SCT", "Laterality")

  @spec left_anterior_descending_artery() :: Code.t()
  def left_anterior_descending_artery,
    do: Code.new("53655008", "SCT", "Left anterior descending coronary artery")

  @spec left_circumflex_artery() :: Code.t()
  def left_circumflex_artery,
    do: Code.new("91748004", "SCT", "Left circumflex coronary artery")

  @spec left_eye() :: Code.t()
  def left_eye, do: Code.new("8966001", "SCT", "Left eye")

  @spec left_main_coronary_artery() :: Code.t()
  def left_main_coronary_artery, do: Code.new("6685003", "SCT", "Left main coronary artery")

  @spec left_ventricle() :: Code.t()
  def left_ventricle, do: Code.new("87878005", "SCT", "Left ventricle structure")

  @spec lesion() :: Code.t()
  def lesion, do: Code.new("52988006", "SCT", "Lesion")

  @spec lesion_size() :: Code.t()
  def lesion_size, do: Code.new("246120007", "SCT", "Lesion size")

  @spec likert_score() :: Code.t()
  def likert_score, do: Code.new("126423", "DCM", "Likert Score")

  @spec localized_finding() :: Code.t()
  def localized_finding, do: Code.new("126403", "DCM", "Localized Finding")

  @spec log_entry() :: Code.t()
  def log_entry, do: Code.new("121146", "DCM", "Log Entry")

  @spec log_entry_datetime() :: Code.t()
  def log_entry_datetime, do: Code.new("121147", "DCM", "Log Entry DateTime")

  @spec lumen_area() :: Code.t()
  def lumen_area, do: Code.new("122151", "DCM", "Lumen Area")

  @spec lv_ejection_fraction() :: Code.t()
  def lv_ejection_fraction, do: Code.new("10230-1", "LN", "Left ventricular Ejection fraction")

  @spec lv_end_diastolic_pressure() :: Code.t()
  def lv_end_diastolic_pressure,
    do: Code.new("8440-2", "LN", "Left ventricular End diastolic pressure")

  @spec lv_findings() :: Code.t()
  def lv_findings, do: Code.new("122157", "DCM", "LV Findings")

  @spec lv_internal_dimension_diastole() :: Code.t()
  def lv_internal_dimension_diastole,
    do: Code.new("18083-9", "LN", "Left ventricular Internal dimension end diastole")

  @spec lv_internal_dimension_systole() :: Code.t()
  def lv_internal_dimension_systole,
    do: Code.new("18085-4", "LN", "Left ventricular Internal dimension end systole")

  @spec lv_posterior_wall_thickness() :: Code.t()
  def lv_posterior_wall_thickness,
    do: Code.new("18158-9", "LN", "Left ventricular posterior wall thickness end diastole")

  @spec macular_grid_measurement() :: Code.t()
  def macular_grid_measurement, do: Code.new("111700", "DCM", "Macular Grid Measurement")

  # Macular Grid Thickness and Volume Report codes (TID 2100)

  @spec macular_grid_report() :: Code.t()
  def macular_grid_report,
    do: Code.new("OPT Macular Grid", "99RPT", "Macular Grid Thickness and Volume Report")

  # CAD template codes (TID 4000, TID 4100, and sub-templates)

  @spec mammography_cad_report() :: Code.t()
  def mammography_cad_report, do: Code.new("111023", "DCM", "Mammography CAD Report")

  # Breast finding types (CID 6014)

  @spec mass() :: Code.t()
  def mass, do: Code.new("4147007", "SCT", "Mass")

  @spec mean_blood_pressure() :: Code.t()
  def mean_blood_pressure, do: Code.new("8478-0", "LN", "Mean blood pressure")

  @spec mean_ctdi_vol() :: Code.t()
  def mean_ctdi_vol, do: Code.new("113830", "DCM", "Mean CTDIvol")

  @spec mean_ctdivol() :: Code.t()
  def mean_ctdivol, do: Code.new("113830", "DCM", "Mean CTDIvol")

  @spec mean_gradient() :: Code.t()
  def mean_gradient, do: Code.new("373098007", "SCT", "Mean gradient")

  @spec measurement_section() :: Code.t()
  def measurement_section, do: Code.new("126061", "DCM", "Measurement Section")

  @spec medication_administered() :: Code.t()
  def medication_administered, do: Code.new("18610-6", "LN", "Medication administered")

  @spec mgy() :: Code.t()
  def mgy, do: Code.new("mGy", "UCUM", "mGy")

  @spec mgy_cm() :: Code.t()
  def mgy_cm, do: Code.new("mGy.cm", "UCUM", "mGy.cm")

  @spec micrometer() :: Code.t()
  def micrometer, do: Code.new("um", "UCUM", "micrometer")

  @spec milliampere() :: Code.t()
  def milliampere, do: Code.new("mA", "UCUM", "mA")

  @spec millimeter() :: Code.t()
  def millimeter, do: Code.new("mm", "UCUM", "mm")

  @spec mitral_valve() :: Code.t()
  def mitral_valve, do: Code.new("91134007", "SCT", "Mitral valve structure")

  @spec mmhg() :: Code.t()
  def mmhg, do: Code.new("mm[Hg]", "UCUM", "mmHg")

  @spec monitoring_parameter() :: Code.t()
  def monitoring_parameter, do: Code.new("128171", "DCM", "Monitoring Parameter")

  @spec myocardial_mass() :: Code.t()
  def myocardial_mass, do: Code.new("10236-8", "LN", "Myocardial Mass")

  @spec narrative_summary() :: Code.t()
  def narrative_summary, do: Code.new("111043", "DCM", "Narrative Summary")

  @spec nodule() :: Code.t()
  def nodule, do: Code.new("27925004", "SCT", "Nodule")

  @spec not_for_presentation() :: Code.t()
  def not_for_presentation, do: Code.new("111151", "DCM", "Not for Presentation")

  # OB-GYN Ultrasound Report codes (TID 5000)

  @spec obgyn_ultrasound_report() :: Code.t()
  def obgyn_ultrasound_report,
    do: Code.new("11525-3", "LN", "OB-GYN Ultrasound Procedure Report")

  @spec organ_depth() :: Code.t()
  def organ_depth, do: Code.new("M-02580", "SRT", "Depth")

  @spec organ_dose() :: Code.t()
  def organ_dose, do: Code.new("113840", "DCM", "Organ Dose")

  @spec organ_dose_estimate() :: Code.t()
  def organ_dose_estimate, do: Code.new("113504", "DCM", "Organ Dose Information")

  @spec organ_length() :: Code.t()
  def organ_length, do: Code.new("M-02550", "SRT", "Length")

  @spec organ_volume() :: Code.t()
  def organ_volume, do: Code.new("118565006", "SCT", "Volume")

  @spec organ_width() :: Code.t()
  def organ_width, do: Code.new("M-02560", "SRT", "Width")

  @spec overall_assessment() :: Code.t()
  def overall_assessment, do: Code.new("111037", "DCM", "Overall Assessment")

  @spec parity() :: Code.t()
  def parity, do: Code.new("11977-6", "LN", "Parity")

  @spec patient_characteristics() :: Code.t()
  def patient_characteristics, do: Code.new("121070", "DCM", "Patient Characteristics")

  @spec patient_history() :: Code.t()
  def patient_history, do: Code.new("121060", "DCM", "History")

  # TID 10030 Patient Radiation Dose Report codes

  @spec patient_radiation_dose_report() :: Code.t()
  def patient_radiation_dose_report,
    do: Code.new("113701", "DCM", "Patient Radiation Dose Report")

  @spec patient_state() :: Code.t()
  def patient_state, do: Code.new("11323-3", "LN", "Health status")

  @spec patient_weight() :: Code.t()
  def patient_weight, do: Code.new("27113001", "SCT", "Body weight")

  @spec pci_procedure() :: Code.t()
  def pci_procedure, do: Code.new("122152", "DCM", "PCI Procedure")

  @spec peak_systolic_velocity() :: Code.t()
  def peak_systolic_velocity,
    do: Code.new("11726-7", "LN", "Peak systolic velocity")

  @spec peak_velocity() :: Code.t()
  def peak_velocity, do: Code.new("34141-2", "LN", "Peak velocity")

  # TID 5220 — Pediatric, Fetal and Congenital Cardiac US Report

  @spec pediatric_cardiac_us_report() :: Code.t()
  def pediatric_cardiac_us_report,
    do: Code.new("125200", "DCM", "Pediatric, Fetal and Congenital Cardiac Ultrasound Report")

  @spec pelvis_and_uterus() :: Code.t()
  def pelvis_and_uterus, do: Code.new("121074", "DCM", "Pelvis and Uterus")

  @spec percent() :: Code.t()
  def percent, do: Code.new("%", "UCUM", "percent")

  @spec performed_imaging_agent_admin() :: Code.t()
  def performed_imaging_agent_admin,
    do: Code.new("113520", "DCM", "Performed Imaging Agent Administration")

  @spec perfusion_analysis_section() :: Code.t()
  def perfusion_analysis_section, do: Code.new("113694", "DCM", "Perfusion Analysis")

  @spec peripheral_zone() :: Code.t()
  def peripheral_zone, do: Code.new("279706003", "SCT", "Peripheral zone of prostate")

  @spec phantom_type() :: Code.t()
  def phantom_type, do: Code.new("113835", "DCM", "CTDIw Phantom Type")

  @spec physiological_monitoring() :: Code.t()
  def physiological_monitoring, do: Code.new("128170", "DCM", "Physiological Monitoring")

  @spec pirads_assessment() :: Code.t()
  def pirads_assessment, do: Code.new("126400", "DCM", "PI-RADS Assessment Category")

  @spec pirads_category_1() :: Code.t()
  def pirads_category_1, do: Code.new("126410", "DCM", "Very low")

  @spec pirads_category_2() :: Code.t()
  def pirads_category_2, do: Code.new("126411", "DCM", "Low")

  @spec pirads_category_3() :: Code.t()
  def pirads_category_3, do: Code.new("126412", "DCM", "Intermediate")

  @spec pirads_category_4() :: Code.t()
  def pirads_category_4, do: Code.new("126413", "DCM", "High")

  @spec pirads_category_5() :: Code.t()
  def pirads_category_5, do: Code.new("126414", "DCM", "Very high")

  @spec placenta_location() :: Code.t()
  def placenta_location, do: Code.new("11969-3", "LN", "Placenta location")

  @spec planned_dose() :: Code.t()
  def planned_dose, do: Code.new("113502", "DCM", "Planned Dose")

  # Imaging Agent Administration codes (TID 11001, TID 11002, TID 11003, TID 11020, TID 11021)

  @spec planned_imaging_agent_admin() :: Code.t()
  def planned_imaging_agent_admin,
    do: Code.new("113501", "DCM", "Planned Imaging Agent Administration")

  @spec planned_volume() :: Code.t()
  def planned_volume, do: Code.new("113503", "DCM", "Planned Volume")

  @spec planning_measurement() :: Code.t()
  def planning_measurement, do: Code.new("122346", "DCM", "Planning measurement")

  @spec plaque_burden() :: Code.t()
  def plaque_burden, do: Code.new("122155", "DCM", "Plaque Burden")

  @spec plaque_type() :: Code.t()
  def plaque_type, do: Code.new("112176", "DCM", "Plaque Type")

  @spec polyp_candidate() :: Code.t()
  def polyp_candidate, do: Code.new("112172", "DCM", "Polyp")

  @spec polyp_size() :: Code.t()
  def polyp_size, do: Code.new("246120007", "SCT", "Nodule size")

  @spec post_coordinated_measurements() :: Code.t()
  def post_coordinated_measurements,
    do: Code.new("125302", "DCM", "Post-coordinated Measurements")

  @spec pre_coordinated_measurements() :: Code.t()
  def pre_coordinated_measurements,
    do: Code.new("125301", "DCM", "Pre-coordinated Measurements")

  # TID 8101 — Preclinical Small Animal Acquisition Context

  @spec preclinical_acquisition_context() :: Code.t()
  def preclinical_acquisition_context,
    do: Code.new("128101", "DCM", "Preclinical Small Animal Acquisition Context")

  @spec prescription_for_eye() :: Code.t()
  def prescription_for_eye, do: Code.new("70947-5", "LN", "Eye prescription")

  @spec presentation_required() :: Code.t()
  def presentation_required, do: Code.new("111150", "DCM", "Presentation Required")

  @spec pressure_gradient() :: Code.t()
  def pressure_gradient, do: Code.new("122172", "DCM", "Pressure Gradient")

  @spec prior_biopsy() :: Code.t()
  def prior_biopsy, do: Code.new("65854-2", "LN", "Prior biopsy")

  @spec prism_base() :: Code.t()
  def prism_base, do: Code.new("246224005", "SCT", "Prism base direction")

  @spec prism_diopter() :: Code.t()
  def prism_diopter, do: Code.new("[p'diop]", "UCUM", "prism diopter")

  @spec prism_power() :: Code.t()
  def prism_power, do: Code.new("246223004", "SCT", "Prism power")

  @spec probability_of_malignancy() :: Code.t()
  def probability_of_malignancy, do: Code.new("111047", "DCM", "Probability of malignancy")

  @spec procedure_action() :: Code.t()
  def procedure_action, do: Code.new("121148", "DCM", "Procedure Action")

  # Procedure Log codes (TID 3001)

  @spec procedure_log() :: Code.t()
  def procedure_log, do: Code.new("121145", "DCM", "Procedure Log")

  @spec procedure_summary() :: Code.t()
  def procedure_summary, do: Code.new("121060", "DCM", "History")

  @spec prostate_imaging_findings() :: Code.t()
  def prostate_imaging_findings, do: Code.new("126200", "DCM", "Prostate Imaging Findings")

  # Prostate Multiparametric MR Imaging Report codes (TID 4300)

  @spec prostate_mr_report() :: Code.t()
  def prostate_mr_report, do: Code.new("72230-6", "LN", "MR Prostate")

  @spec prostate_volume() :: Code.t()
  def prostate_volume, do: Code.new("118565006", "SCT", "Volume")

  @spec psa_density() :: Code.t()
  def psa_density, do: Code.new("126401", "DCM", "PSA Density")

  @spec psa_level() :: Code.t()
  def psa_level, do: Code.new("2857-1", "LN", "Prostate specific Ag")

  @spec pulmonic_valve() :: Code.t()
  def pulmonic_valve, do: Code.new("39057004", "SCT", "Pulmonary valve structure")

  @spec pulsatility_index() :: Code.t()
  def pulsatility_index,
    do: Code.new("20355-4", "LN", "Pulsatility index")

  @spec pulses() :: Code.t()
  def pulses, do: Code.new("{pulses}", "UCUM", "pulses")

  @spec quality_assessment() :: Code.t()
  def quality_assessment, do: Code.new("363679005", "SCT", "Quality assessment")

  @spec radiation_dose_estimate() :: Code.t()
  def radiation_dose_estimate, do: Code.new("113703", "DCM", "Radiation Dose Estimate")

  @spec radiation_exposure() :: Code.t()
  def radiation_exposure, do: Code.new("113507", "DCM", "CT Radiation Dose")

  @spec radionuclide() :: Code.t()
  def radionuclide, do: Code.new("89457008", "SCT", "Radionuclide")

  @spec radiopharmaceutical() :: Code.t()
  def radiopharmaceutical, do: Code.new("349358000", "SCT", "Radiopharmaceutical")

  @spec radiopharmaceutical_administration_event() :: Code.t()
  def radiopharmaceutical_administration_event,
    do: Code.new("113502", "DCM", "Radiopharmaceutical Administration Event")

  # TID 10021 Radiopharmaceutical Radiation Dose Report codes

  @spec radiopharmaceutical_dose_report() :: Code.t()
  def radiopharmaceutical_dose_report,
    do: Code.new("113500", "DCM", "Radiopharmaceutical Radiation Dose Report")

  @spec rendering_intent() :: Code.t()
  def rendering_intent, do: Code.new("111056", "DCM", "Rendering Intent")

  @spec report_narrative() :: Code.t()
  def report_narrative, do: Code.new("111412", "DCM", "Narrative Summary")

  @spec resistive_index() :: Code.t()
  def resistive_index,
    do: Code.new("20354-7", "LN", "Resistive index")

  @spec retinal_thickness() :: Code.t()
  def retinal_thickness, do: Code.new("410668003", "SCT", "Retinal thickness")

  @spec retinal_volume() :: Code.t()
  def retinal_volume, do: Code.new("121216", "DCM", "Volume")

  @spec right_coronary_artery() :: Code.t()
  def right_coronary_artery, do: Code.new("12800006", "SCT", "Right coronary artery")

  @spec right_eye() :: Code.t()
  def right_eye, do: Code.new("81745001", "SCT", "Right eye")

  @spec right_ventricle() :: Code.t()
  def right_ventricle, do: Code.new("53085002", "SCT", "Right ventricular structure")

  @spec route_of_administration() :: Code.t()
  def route_of_administration, do: Code.new("410675002", "SCT", "Route of administration")

  @spec scanning_length() :: Code.t()
  def scanning_length, do: Code.new("113825", "DCM", "Scanning Length")

  @spec seconds() :: Code.t()
  def seconds, do: Code.new("s", "UCUM", "s")

  @spec seminal_vesicle_invasion() :: Code.t()
  def seminal_vesicle_invasion, do: Code.new("126430", "DCM", "Seminal Vesicle Invasion")

  @spec shear_wave_elasticity() :: Code.t()
  def shear_wave_elasticity, do: Code.new("125371", "DCM", "Shear Wave Elasticity")

  @spec shear_wave_velocity() :: Code.t()
  def shear_wave_velocity, do: Code.new("125370", "DCM", "Shear Wave Velocity")

  @spec signal_quality() :: Code.t()
  def signal_quality, do: Code.new("251602002", "SCT", "Signal quality")

  # TID 5300 — Simplified Echo Procedure Report

  @spec simplified_echo_report() :: Code.t()
  def simplified_echo_report,
    do: Code.new("125300", "DCM", "Simplified Echo Procedure Report")

  @spec single_deepest_pocket() :: Code.t()
  def single_deepest_pocket,
    do: Code.new("11817-4", "LN", "Single deepest pocket")

  @spec single_image_finding() :: Code.t()
  def single_image_finding, do: Code.new("111059", "DCM", "Single Image Finding")

  # Spectacle Prescription codes (TID 2020)

  @spec spectacle_prescription_report() :: Code.t()
  def spectacle_prescription_report,
    do: Code.new("70946-7", "LN", "Spectacle prescription")

  @spec sphere_power() :: Code.t()
  def sphere_power, do: Code.new("251795007", "SCT", "Sphere power")

  @spec start_datetime() :: Code.t()
  def start_datetime, do: Code.new("113509", "DCM", "Start DateTime")

  @spec stationary_acquisition() :: Code.t()
  def stationary_acquisition, do: Code.new("113806", "DCM", "Stationary Acquisition")

  @spec stenosis_grade() :: Code.t()
  def stenosis_grade,
    do: Code.new("18228-7", "LN", "Degree of stenosis")

  @spec stenosis_severity() :: Code.t()
  def stenosis_severity, do: Code.new("246112005", "SCT", "Severity of stenosis")

  @spec stent_placed() :: Code.t()
  def stent_placed, do: Code.new("122154", "DCM", "Stent Placed")

  @spec stroke_volume() :: Code.t()
  def stroke_volume, do: Code.new("90096-0", "LN", "Stroke Volume")

  # TID 5320 — Structural Heart Measurement Report

  @spec structural_heart_report() :: Code.t()
  def structural_heart_report,
    do: Code.new("125320", "DCM", "Structural Heart Measurement Report")

  @spec successful_analyses_performed() :: Code.t()
  def successful_analyses_performed,
    do: Code.new("111034", "DCM", "Successful Analyses Performed")

  @spec successful_detections_performed() :: Code.t()
  def successful_detections_performed,
    do: Code.new("111033", "DCM", "Successful Detections Performed")

  @spec summary() :: Code.t()
  def summary, do: Code.new("121077", "DCM", "Conclusion")

  @spec systolic_blood_pressure() :: Code.t()
  def systolic_blood_pressure, do: Code.new("8480-6", "LN", "Systolic blood pressure")

  @spec t2w_signal_score() :: Code.t()
  def t2w_signal_score, do: Code.new("126420", "DCM", "T2W Signal Score")

  @spec target_organ() :: Code.t()
  def target_organ, do: Code.new("363698007", "SCT", "Finding Site")

  @spec timi_flow_grade() :: Code.t()
  def timi_flow_grade, do: Code.new("122155", "DCM", "TIMI Flow Grade")

  @spec total_fluoro_time() :: Code.t()
  def total_fluoro_time, do: Code.new("113730", "DCM", "Total Fluoro Time")

  @spec total_number_of_radiographic_frames() :: Code.t()
  def total_number_of_radiographic_frames,
    do: Code.new("113731", "DCM", "Total Number of Radiographic Frames")

  @spec total_volume() :: Code.t()
  def total_volume, do: Code.new("121217", "DCM", "Total Volume")

  # Transcribed Diagnostic Imaging Report codes (TID 2005)

  @spec transcribed_diagnostic_imaging_report() :: Code.t()
  def transcribed_diagnostic_imaging_report,
    do: Code.new("18782-3", "LN", "Radiology Study observation (narrative)")

  @spec transition_zone() :: Code.t()
  def transition_zone, do: Code.new("279709005", "SCT", "Transition zone of prostate")

  @spec tricuspid_valve() :: Code.t()
  def tricuspid_valve, do: Code.new("46030003", "SCT", "Tricuspid valve structure")

  @spec tube_current() :: Code.t()
  def tube_current, do: Code.new("113734", "DCM", "X-Ray Tube Current")

  @spec valve_area() :: Code.t()
  def valve_area, do: Code.new("399023004", "SCT", "Valve area")

  @spec vascular_analysis_section() :: Code.t()
  def vascular_analysis_section, do: Code.new("113692", "DCM", "Vascular Analysis")

  @spec vascular_section() :: Code.t()
  def vascular_section,
    do: Code.new("121196", "DCM", "Vascular Properties")

  # Vascular Ultrasound Report codes (TID 5100)

  @spec vascular_ultrasound_report() :: Code.t()
  def vascular_ultrasound_report,
    do: Code.new("36440-4", "LN", "Vascular Ultrasound Report")

  @spec ventricular_analysis_section() :: Code.t()
  def ventricular_analysis_section, do: Code.new("113693", "DCM", "Ventricular Analysis")

  @spec vessel() :: Code.t()
  def vessel, do: Code.new("59820001", "SCT", "Blood Vessel")

  @spec vessel_area() :: Code.t()
  def vessel_area, do: Code.new("122153", "DCM", "Vessel Area")

  @spec vessel_branch() :: Code.t()
  def vessel_branch, do: Code.new("91726008", "SCT", "Branch of")

  @spec vessel_diameter() :: Code.t()
  def vessel_diameter,
    do: Code.new("57990-1", "LN", "Vessel lumen diameter")

  @spec vessel_patency() :: Code.t()
  def vessel_patency,
    do: Code.new("246100006", "SCT", "Patency")

  @spec vessel_segment() :: Code.t()
  def vessel_segment, do: Code.new("363704007", "SCT", "Procedure site")

  @spec wall_motion_abnormality() :: Code.t()
  def wall_motion_abnormality, do: Code.new("F-32040", "SRT", "Wall motion abnormality")

  @spec wall_motion_analysis() :: Code.t()
  def wall_motion_analysis, do: Code.new("125205", "DCM", "Wall Motion Analysis")

  @spec wall_motion_score_index() :: Code.t()
  def wall_motion_score_index, do: Code.new("125209", "DCM", "Wall Motion Score Index")

  @spec wall_motion_segment() :: Code.t()
  def wall_motion_segment, do: Code.new("125206", "DCM", "Wall Motion Segment")

  @spec waveform_morphology() :: Code.t()
  def waveform_morphology,
    do: Code.new("251104001", "SCT", "Waveform morphology")

  # Radiation Dose Report codes (TID 10001, TID 10002, TID 10003, TID 10011-10014)

  @spec xray_radiation_dose_report() :: Code.t()
  def xray_radiation_dose_report,
    do: Code.new("113701", "DCM", "X-Ray Radiation Dose Report")

  # Observation Context codes (TID 1001-1009)

  @spec person_observer_login_name() :: Code.t()
  def person_observer_login_name, do: Code.new("128774", "DCM", "Person Observer's Login Name")

  @spec person_observer_organization_name() :: Code.t()
  def person_observer_organization_name,
    do: Code.new("121009", "DCM", "Person Observer's Organization Name")

  @spec person_observer_role_in_organization() :: Code.t()
  def person_observer_role_in_organization,
    do: Code.new("121010", "DCM", "Person Observer's Role in the Organization")

  @spec person_observer_role_in_procedure() :: Code.t()
  def person_observer_role_in_procedure,
    do: Code.new("121011", "DCM", "Person Observer's Role in this Procedure")

  @spec identifier_within_role() :: Code.t()
  def identifier_within_role,
    do: Code.new("128775", "DCM", "Identifier within Person Observer's Role")

  @spec device_physical_location() :: Code.t()
  def device_physical_location,
    do: Code.new("121017", "DCM", "Device Physical Location During Observation")

  @spec device_role_in_procedure() :: Code.t()
  def device_role_in_procedure, do: Code.new("113876", "DCM", "Device Role in Procedure")

  @spec station_ae_title() :: Code.t()
  def station_ae_title, do: Code.new("110119", "DCM", "Station AE Title")

  @spec device_manufacturer_class_uid() :: Code.t()
  def device_manufacturer_class_uid,
    do: Code.new("121061", "DCM", "Device Manufacturer Class UID")

  # TID 1005 Procedure Study Context codes

  @spec procedure_study_instance_uid() :: Code.t()
  def procedure_study_instance_uid, do: Code.new("121018", "DCM", "Procedure Study Instance UID")

  @spec procedure_study_component_uid() :: Code.t()
  def procedure_study_component_uid,
    do: Code.new("121019", "DCM", "Procedure Study Component UID")

  @spec placer_number() :: Code.t()
  def placer_number, do: Code.new("121020", "DCM", "Placer Number")

  @spec filler_number() :: Code.t()
  def filler_number, do: Code.new("121021", "DCM", "Filler Number")

  @spec accession_number() :: Code.t()
  def accession_number, do: Code.new("121022", "DCM", "Accession Number")

  @spec procedure_code() :: Code.t()
  def procedure_code, do: Code.new("121023", "DCM", "Procedure Code")

  @spec issuer_of_identifier() :: Code.t()
  def issuer_of_identifier, do: Code.new("110190", "DCM", "Issuer of Identifier")

  # TID 1006-1009 Subject Context codes

  @spec subject_class() :: Code.t()
  def subject_class, do: Code.new("121024", "DCM", "Subject Class")

  @spec subject_uid() :: Code.t()
  def subject_uid, do: Code.new("121028", "DCM", "Subject UID")

  @spec subject_name() :: Code.t()
  def subject_name, do: Code.new("121029", "DCM", "Subject Name")

  @spec subject_id() :: Code.t()
  def subject_id, do: Code.new("121030", "DCM", "Subject ID")

  @spec subject_birth_date() :: Code.t()
  def subject_birth_date, do: Code.new("121031", "DCM", "Subject Birth Date")

  @spec subject_sex() :: Code.t()
  def subject_sex, do: Code.new("121032", "DCM", "Subject Sex")

  @spec subject_age() :: Code.t()
  def subject_age, do: Code.new("121033", "DCM", "Subject Age")

  @spec subject_species() :: Code.t()
  def subject_species, do: Code.new("121034", "DCM", "Subject Species")

  @spec subject_breed() :: Code.t()
  def subject_breed, do: Code.new("121035", "DCM", "Subject Breed")

  @spec mother_of_fetus() :: Code.t()
  def mother_of_fetus, do: Code.new("121036", "DCM", "Mother of fetus")

  @spec fetus_id() :: Code.t()
  def fetus_id, do: Code.new("11951-1", "LN", "Fetus ID")

  @spec number_of_fetuses_by_us() :: Code.t()
  def number_of_fetuses_by_us, do: Code.new("11878-6", "LN", "Number of fetuses by US")

  @spec number_of_fetuses() :: Code.t()
  def number_of_fetuses, do: Code.new("55281-0", "LN", "Number of fetuses")

  @spec specimen_uid() :: Code.t()
  def specimen_uid, do: Code.new("121039", "DCM", "Specimen UID")

  @spec specimen_identifier() :: Code.t()
  def specimen_identifier, do: Code.new("121041", "DCM", "Specimen Identifier")

  @spec issuer_of_specimen_identifier() :: Code.t()
  def issuer_of_specimen_identifier,
    do: Code.new("111724", "DCM", "Issuer of Specimen Identifier")

  @spec specimen_type() :: Code.t()
  def specimen_type, do: Code.new("371439000", "SCT", "Specimen type")

  @spec specimen_container_identifier() :: Code.t()
  def specimen_container_identifier,
    do: Code.new("111700", "DCM", "Specimen Container Identifier")

  # -- TID 1200-1211 Language Sub-Template codes ----------------------------

  @spec language() :: Code.t()
  def language, do: Code.new("121046", "DCM", "Language")

  @spec country_of_language() :: Code.t()
  def country_of_language, do: Code.new("121047", "DCM", "Country of Language")

  @spec language_of_value() :: Code.t()
  def language_of_value, do: Code.new("121048", "DCM", "Language of Value")

  @spec equivalent_meaning_of_concept_name() :: Code.t()
  def equivalent_meaning_of_concept_name,
    do: Code.new("121050", "DCM", "Equivalent Meaning of Concept Name")

  @spec equivalent_meaning_of_value() :: Code.t()
  def equivalent_meaning_of_value,
    do: Code.new("121051", "DCM", "Equivalent Meaning of Value")

  # -- TID 1400-1420 Measurement Type Sub-Template codes --------------------

  @spec derivation() :: Code.t()
  def derivation, do: Code.new("121401", "DCM", "Derivation")

  @spec measurement_method() :: Code.t()
  def measurement_method, do: Code.new("370129005", "SCT", "Measurement Method")

  @spec equation_or_table() :: Code.t()
  def equation_or_table, do: Code.new("121424", "DCM", "Equation or Table")

  # -- TID 300-315 Measurement Properties codes -----------------------------

  @spec selection_status() :: Code.t()
  def selection_status, do: Code.new("121402", "DCM", "Selection Status")

  @spec population_description() :: Code.t()
  def population_description, do: Code.new("121405", "DCM", "Population Description")

  @spec measurement_authority() :: Code.t()
  def measurement_authority, do: Code.new("121406", "DCM", "Measurement Authority")

  @spec statistical_description() :: Code.t()
  def statistical_description, do: Code.new("121404", "DCM", "Statistical Description")

  @spec value_for_n() :: Code.t()
  def value_for_n, do: Code.new("121403", "DCM", "Value for N")

  @spec normal_range_upper() :: Code.t()
  def normal_range_upper, do: Code.new("121410", "DCM", "Normal Range Upper Value")

  @spec normal_range_lower() :: Code.t()
  def normal_range_lower, do: Code.new("121411", "DCM", "Normal Range Lower Value")

  @spec normal_range_description() :: Code.t()
  def normal_range_description, do: Code.new("121412", "DCM", "Normal Range Description")

  @spec numerator() :: Code.t()
  def numerator, do: Code.new("121420", "DCM", "Numerator")

  @spec denominator() :: Code.t()
  def denominator, do: Code.new("121421", "DCM", "Denominator")

  @spec table() :: Code.t()
  def table, do: Code.new("121425", "DCM", "Table")

  # -- TID 1501-1502 Measurement Group and Time Point codes -----------------

  @spec time_point() :: Code.t()
  def time_point, do: Code.new("C2348792", "UMLS", "Time Point")

  @spec time_point_type() :: Code.t()
  def time_point_type, do: Code.new("126072", "DCM", "Time Point Type")

  @spec time_point_order() :: Code.t()
  def time_point_order, do: Code.new("126073", "DCM", "Time Point Order")

  @spec subject_time_point_identifier() :: Code.t()
  def subject_time_point_identifier,
    do: Code.new("126070", "DCM", "Subject Time Point Identifier")

  @spec protocol_time_point_identifier() :: Code.t()
  def protocol_time_point_identifier,
    do: Code.new("126071", "DCM", "Protocol Time Point Identifier")

  @spec temporal_offset_from_event() :: Code.t()
  def temporal_offset_from_event,
    do: Code.new("128740", "DCM", "Temporal Offset From Event")

  @spec temporal_event() :: Code.t()
  def temporal_event, do: Code.new("128741", "DCM", "Temporal Event")

  # -- TID 1602-1608 Image Library Descriptor codes -------------------------

  @spec modality() :: Code.t()
  def modality, do: Code.new("121139", "DCM", "Modality")

  @spec frame_of_reference_uid() :: Code.t()
  def frame_of_reference_uid, do: Code.new("112227", "DCM", "Frame of Reference UID")

  @spec pixel_data_rows() :: Code.t()
  def pixel_data_rows, do: Code.new("110910", "DCM", "Pixel Data Rows")

  @spec slice_thickness() :: Code.t()
  def slice_thickness, do: Code.new("112225", "DCM", "Slice Thickness")

  @spec image_laterality() :: Code.t()
  def image_laterality, do: Code.new("111027", "DCM", "Image Laterality")

  @spec patient_orientation_row() :: Code.t()
  def patient_orientation_row,
    do: Code.new("110921", "DCM", "Patient Orientation Row")

  @spec patient_orientation_column() :: Code.t()
  def patient_orientation_column,
    do: Code.new("110922", "DCM", "Patient Orientation Column")

  @spec positioner_primary_angle() :: Code.t()
  def positioner_primary_angle,
    do: Code.new("112011", "DCM", "Positioner Primary Angle")

  @spec positioner_secondary_angle() :: Code.t()
  def positioner_secondary_angle,
    do: Code.new("112012", "DCM", "Positioner Secondary Angle")

  @spec radiographic_view() :: Code.t()
  def radiographic_view, do: Code.new("111031", "DCM", "Radiographic View")

  @spec image_position_patient() :: Code.t()
  def image_position_patient, do: Code.new("110902", "DCM", "Image Position (Patient)")

  @spec image_orientation_patient() :: Code.t()
  def image_orientation_patient,
    do: Code.new("110903", "DCM", "Image Orientation (Patient)")

  @spec pixel_spacing() :: Code.t()
  def pixel_spacing, do: Code.new("110911", "DCM", "Pixel Spacing")

  @spec spacing_between_slices() :: Code.t()
  def spacing_between_slices, do: Code.new("112226", "DCM", "Spacing Between Slices")

  @spec reconstruction_algorithm() :: Code.t()
  def reconstruction_algorithm,
    do: Code.new("113962", "DCM", "Reconstruction Algorithm")

  @spec convolution_kernel() :: Code.t()
  def convolution_kernel, do: Code.new("113951", "DCM", "Convolution Kernel")

  @spec spiral_pitch_factor() :: Code.t()
  def spiral_pitch_factor, do: Code.new("113828", "DCM", "Spiral Pitch Factor")

  @spec echo_time() :: Code.t()
  def echo_time, do: Code.new("110831", "DCM", "Echo Time")

  @spec repetition_time() :: Code.t()
  def repetition_time, do: Code.new("110832", "DCM", "Repetition Time")

  @spec flip_angle() :: Code.t()
  def flip_angle, do: Code.new("110833", "DCM", "Flip Angle")

  @spec inversion_time() :: Code.t()
  def inversion_time, do: Code.new("110834", "DCM", "Inversion Time")

  @spec pulse_sequence_name() :: Code.t()
  def pulse_sequence_name, do: Code.new("110835", "DCM", "Pulse Sequence Name")

  @spec mr_acquisition_type() :: Code.t()
  def mr_acquisition_type, do: Code.new("110836", "DCM", "MR Acquisition Type")

  @spec radiopharmaceutical_volume() :: Code.t()
  def radiopharmaceutical_volume,
    do: Code.new("123005", "DCM", "Radiopharmaceutical Volume")

  @spec radiopharmaceutical_start_datetime() :: Code.t()
  def radiopharmaceutical_start_datetime,
    do: Code.new("123004", "DCM", "Radiopharmaceutical Start DateTime")

  @spec diffusion_b_value() :: Code.t()
  def diffusion_b_value, do: Code.new("113043", "DCM", "Diffusion b-value")

  @spec adc_map_indicator() :: Code.t()
  def adc_map_indicator, do: Code.new("113041", "DCM", "Apparent Diffusion Coefficient")

  @spec dynamic_contrast_enhanced() :: Code.t()
  def dynamic_contrast_enhanced,
    do: Code.new("113054", "DCM", "Dynamic Contrast Enhanced")

  # -- UCUM unit codes for Image Library Descriptors ------------------------

  @spec degrees() :: Code.t()
  def degrees, do: Code.new("deg", "UCUM", "degree")

  @spec kv() :: Code.t()
  def kv, do: Code.new("kV", "UCUM", "kilovolt")

  @spec millisecond() :: Code.t()
  def millisecond, do: Code.new("ms", "UCUM", "millisecond")

  # Domain sub-template codes (iterations 11-15)

  @spec a_wave_velocity() :: Code.t()
  def a_wave_velocity, do: Code.new("122304", "DCM", "A-wave velocity")

  @spec adequate_quality() :: Code.t()
  def adequate_quality, do: Code.new("111052", "DCM", "Adequate")

  @spec agatston_unit() :: Code.t()
  def agatston_unit, do: Code.new("1", "UCUM", "Agatston unit")

  @spec akinesis() :: Code.t()
  def akinesis, do: Code.new("122311", "DCM", "Akinesis")

  @spec algorithm_parameters() :: Code.t()
  def algorithm_parameters, do: Code.new("111002", "DCM", "Algorithm Parameters")

  @spec almost_entirely_fat() :: Code.t()
  def almost_entirely_fat, do: Code.new("111044", "DCM", "Almost entirely fat")

  @spec area_stenosis() :: Code.t()
  def area_stenosis, do: Code.new("122410", "DCM", "Area Stenosis")

  @spec beats_per_minute() :: Code.t()
  def beats_per_minute, do: Code.new("/min", "UCUM", "beats per minute")

  @spec breast_density() :: Code.t()
  def breast_density, do: Code.new("111043", "DCM", "Breast Density")

  @spec cad_operating_point() :: Code.t()
  def cad_operating_point, do: Code.new("111055", "DCM", "CAD Operating Point")

  @spec cad_processing_unsuccessful() :: Code.t()
  def cad_processing_unsuccessful,
    do: Code.new("111054", "DCM", "CAD Processing and Findings Summary")

  @spec calcified_plaque() :: Code.t()
  def calcified_plaque, do: Code.new("122213", "DCM", "Calcified")

  @spec cm() :: Code.t()
  def cm, do: Code.new("cm", "UCUM", "cm")

  @spec cm_per_s() :: Code.t()
  def cm_per_s, do: Code.new("cm/s", "UCUM", "cm/s")

  @spec common_carotid_artery() :: Code.t()
  def common_carotid_artery, do: Code.new("32062004", "SCT", "Common carotid artery")

  @spec comparison_to_prior() :: Code.t()
  def comparison_to_prior, do: Code.new("122161", "DCM", "Comparison to Prior Study")

  @spec cubic_mm() :: Code.t()
  def cubic_mm, do: Code.new("mm3", "UCUM", "mm3")

  @spec deceleration_time() :: Code.t()
  def deceleration_time, do: Code.new("122306", "DCM", "Deceleration time")

  @spec detection_sensitivity() :: Code.t()
  def detection_sensitivity, do: Code.new("111048", "DCM", "Detection Sensitivity")

  @spec detection_specificity() :: Code.t()
  def detection_specificity, do: Code.new("111049", "DCM", "Detection Specificity")

  @spec diameter_stenosis() :: Code.t()
  def diameter_stenosis, do: Code.new("122409", "DCM", "Diameter Stenosis")

  @spec dyskinesis() :: Code.t()
  def dyskinesis, do: Code.new("122312", "DCM", "Dyskinesis")

  @spec e_a_ratio() :: Code.t()
  def e_a_ratio, do: Code.new("122305", "DCM", "E/A ratio")

  @spec e_wave_velocity() :: Code.t()
  def e_wave_velocity, do: Code.new("122303", "DCM", "E-wave velocity")

  @spec ecg_summary() :: Code.t()
  def ecg_summary, do: Code.new("122164", "DCM", "ECG Summary")

  @spec echo_measurement() :: Code.t()
  def echo_measurement, do: Code.new("122302", "DCM", "Echo Measurement")

  @spec echo_section() :: Code.t()
  def echo_section, do: Code.new("122301", "DCM", "Echo Section")

  @spec equivocal_stress_test() :: Code.t()
  def equivocal_stress_test, do: Code.new("122160", "DCM", "Equivocal")

  @spec exercise_duration() :: Code.t()
  def exercise_duration, do: Code.new("122144", "DCM", "Exercise Duration")

  @spec exercise_mets() :: Code.t()
  def exercise_mets, do: Code.new("122146", "DCM", "Metabolic Equivalents")

  @spec exercise_stress_test() :: Code.t()
  def exercise_stress_test, do: Code.new("40701008", "SCT", "Echocardiography stress test")

  @spec external_carotid_artery() :: Code.t()
  def external_carotid_artery, do: Code.new("22286001", "SCT", "External carotid artery")

  @spec extremely_dense() :: Code.t()
  def extremely_dense, do: Code.new("111047", "DCM", "Extremely dense")

  @spec false_positive_rate() :: Code.t()
  def false_positive_rate, do: Code.new("111050", "DCM", "False Positive Rate")

  @spec femoral_artery() :: Code.t()
  def femoral_artery, do: Code.new("7657000", "SCT", "Femoral artery")

  @spec fibrous_plaque() :: Code.t()
  def fibrous_plaque, do: Code.new("122214", "DCM", "Fibrous")

  @spec global_longitudinal_strain() :: Code.t()
  def global_longitudinal_strain, do: Code.new("122313", "DCM", "Global Longitudinal Strain")

  @spec graft_destination() :: Code.t()
  def graft_destination, do: Code.new("122415", "DCM", "Graft Destination")

  @spec graft_origin() :: Code.t()
  def graft_origin, do: Code.new("122414", "DCM", "Graft Origin")

  @spec graft_patency() :: Code.t()
  def graft_patency, do: Code.new("122416", "DCM", "Graft Patency")

  @spec graft_type() :: Code.t()
  def graft_type, do: Code.new("122411", "DCM", "Graft Type")

  @spec grams() :: Code.t()
  def grams, do: Code.new("g", "UCUM", "g")

  @spec heterogeneously_dense() :: Code.t()
  def heterogeneously_dense, do: Code.new("111046", "DCM", "Heterogeneously dense")

  @spec hypokinesis() :: Code.t()
  def hypokinesis, do: Code.new("122310", "DCM", "Hypokinesis")

  @spec image_quality() :: Code.t()
  def image_quality, do: Code.new("111051", "DCM", "Image Quality")

  @spec imaging_summary() :: Code.t()
  def imaging_summary, do: Code.new("122163", "DCM", "Imaging Summary")

  @spec inadequate_quality() :: Code.t()
  def inadequate_quality, do: Code.new("111053", "DCM", "Inadequate")

  @spec individual_impression() :: Code.t()
  def individual_impression, do: Code.new("111038", "DCM", "Individual Impression")

  @spec internal_carotid_artery() :: Code.t()
  def internal_carotid_artery, do: Code.new("86117002", "SCT", "Internal carotid artery")

  @spec intima_media_thickness() :: Code.t()
  def intima_media_thickness, do: Code.new("122408", "DCM", "Intima-Media Thickness")

  @spec ivus_lesion() :: Code.t()
  def ivus_lesion, do: Code.new("122202", "DCM", "IVUS Lesion")

  @spec ivus_vessel() :: Code.t()
  def ivus_vessel, do: Code.new("122201", "DCM", "IVUS Vessel")

  @spec ivus_volume() :: Code.t()
  def ivus_volume, do: Code.new("122217", "DCM", "IVUS Volume Measurement")

  @spec kg() :: Code.t()
  def kg, do: Code.new("kg", "UCUM", "kg")

  @spec left_atrium() :: Code.t()
  def left_atrium, do: Code.new("82471001", "SCT", "Left atrium")

  @spec left_breast() :: Code.t()
  def left_breast, do: Code.new("80248007", "SCT", "Left breast")

  @spec lipid_rich_plaque() :: Code.t()
  def lipid_rich_plaque, do: Code.new("122215", "DCM", "Lipid Rich")

  @spec lumen_volume() :: Code.t()
  def lumen_volume, do: Code.new("122218", "DCM", "Lumen Volume")

  @spec lv_end_diastolic_dimension() :: Code.t()
  def lv_end_diastolic_dimension,
    do: Code.new("29468-6", "LN", "LV internal end-diastolic dimension")

  @spec lv_end_systolic_dimension() :: Code.t()
  def lv_end_systolic_dimension,
    do: Code.new("29469-4", "LN", "LV internal end-systolic dimension")

  @spec lv_mass() :: Code.t()
  def lv_mass, do: Code.new("10231-9", "LN", "LV mass")

  @spec lvef() :: Code.t()
  def lvef, do: Code.new("10230-1", "LN", "Left ventricular ejection fraction")

  @spec m_sq() :: Code.t()
  def m_sq, do: Code.new("m2", "UCUM", "m2")

  @spec maximum_lumen_diameter() :: Code.t()
  def maximum_lumen_diameter, do: Code.new("122209", "DCM", "Maximum Lumen Diameter")

  @spec minimum_lumen_diameter() :: Code.t()
  def minimum_lumen_diameter, do: Code.new("122208", "DCM", "Minimum Lumen Diameter")

  @spec milligram() :: Code.t()
  def milligram, do: Code.new("mg", "UCUM", "milligram")

  @spec milliliter() :: Code.t()
  def milliliter, do: Code.new("mL", "UCUM", "milliliter")

  @spec minutes() :: Code.t()
  def minutes, do: Code.new("min", "UCUM", "minutes")

  @spec mixed_plaque() :: Code.t()
  def mixed_plaque, do: Code.new("122216", "DCM", "Mixed")

  @spec mm() :: Code.t()
  def mm, do: Code.new("mm", "UCUM", "mm")

  @spec ms() :: Code.t()
  def ms, do: Code.new("ms", "UCUM", "ms")

  @spec negative_stress_test() :: Code.t()
  def negative_stress_test, do: Code.new("122157", "DCM", "Negative")

  @spec normal_wall_motion() :: Code.t()
  def normal_wall_motion, do: Code.new("122309", "DCM", "Normal")

  @spec occluded() :: Code.t()
  def occluded, do: Code.new("122418", "DCM", "Occluded")

  @spec patent() :: Code.t()
  def patent, do: Code.new("122417", "DCM", "Patent")

  @spec peak_heart_rate() :: Code.t()
  def peak_heart_rate, do: Code.new("8867-4", "LN", "Heart rate")

  @spec peak_phase() :: Code.t()
  def peak_phase, do: Code.new("122151", "DCM", "Peak")

  @spec percent_max_predicted_hr() :: Code.t()
  def percent_max_predicted_hr,
    do: Code.new("122147", "DCM", "Percent Max Predicted Heart Rate")

  @spec perfusion_finding() :: Code.t()
  def perfusion_finding, do: Code.new("122165", "DCM", "Perfusion Finding")

  @spec pharmacological_stress_test() :: Code.t()
  def pharmacological_stress_test,
    do: Code.new("76746007", "SCT", "Cardiovascular stress testing")

  @spec phase_of_exercise() :: Code.t()
  def phase_of_exercise, do: Code.new("122149", "DCM", "Phase of Exercise")

  @spec physiological_summary() :: Code.t()
  def physiological_summary, do: Code.new("122162", "DCM", "Physiological Summary")

  @spec plaque_area() :: Code.t()
  def plaque_area, do: Code.new("122205", "DCM", "Plaque Area")

  @spec plaque_eccentricity_index() :: Code.t()
  def plaque_eccentricity_index, do: Code.new("122211", "DCM", "Plaque Eccentricity Index")

  @spec plaque_morphology() :: Code.t()
  def plaque_morphology, do: Code.new("122212", "DCM", "Plaque Morphology")

  @spec plaque_volume() :: Code.t()
  def plaque_volume, do: Code.new("122220", "DCM", "Plaque Volume")

  @spec positive_stress_test() :: Code.t()
  def positive_stress_test, do: Code.new("122156", "DCM", "Positive")

  @spec probability_of_cancer() :: Code.t()
  def probability_of_cancer, do: Code.new("111056", "DCM", "Probability of Cancer")

  @spec recovery_phase() :: Code.t()
  def recovery_phase, do: Code.new("122152", "DCM", "Recovery")

  @spec remodeling_index() :: Code.t()
  def remodeling_index, do: Code.new("122210", "DCM", "Remodeling Index")

  @spec rest_phase() :: Code.t()
  def rest_phase, do: Code.new("122150", "DCM", "Rest")

  @spec resting_heart_rate() :: Code.t()
  def resting_heart_rate, do: Code.new("122148", "DCM", "Resting Heart Rate")

  @spec right_breast() :: Code.t()
  def right_breast, do: Code.new("73056007", "SCT", "Right breast")

  @spec scattered_fibroglandular() :: Code.t()
  def scattered_fibroglandular,
    do: Code.new("111045", "DCM", "Scattered fibroglandular densities")

  @spec sq_mm() :: Code.t()
  def sq_mm, do: Code.new("mm2", "UCUM", "mm2")

  @spec st_segment_finding() :: Code.t()
  def st_segment_finding, do: Code.new("122153", "DCM", "ST Segment Finding")

  @spec stress_mode() :: Code.t()
  def stress_mode, do: Code.new("122143", "DCM", "Stress Mode")

  @spec stress_protocol() :: Code.t()
  def stress_protocol, do: Code.new("122142", "DCM", "Protocol")

  @spec synthetic_graft() :: Code.t()
  def synthetic_graft, do: Code.new("122412", "DCM", "Synthetic")

  @spec target_heart_rate() :: Code.t()
  def target_heart_rate, do: Code.new("122145", "DCM", "Target Heart Rate")

  @spec test_result() :: Code.t()
  def test_result, do: Code.new("122155", "DCM", "Test Result")

  @spec vascular_measurement_group() :: Code.t()
  def vascular_measurement_group, do: Code.new("122404", "DCM", "Measurement Group")

  @spec vascular_patient_characteristics() :: Code.t()
  def vascular_patient_characteristics,
    do: Code.new("122401", "DCM", "Patient Characteristics")

  @spec vascular_procedure_summary() :: Code.t()
  def vascular_procedure_summary, do: Code.new("122402", "DCM", "Procedure Summary")

  @spec vein_graft() :: Code.t()
  def vein_graft, do: Code.new("122413", "DCM", "Vein")

  @spec vertebral_artery() :: Code.t()
  def vertebral_artery, do: Code.new("85234005", "SCT", "Vertebral artery")

  @spec vessel_lumen_area() :: Code.t()
  def vessel_lumen_area, do: Code.new("122203", "DCM", "Vessel Lumen Area")

  @spec vessel_volume() :: Code.t()
  def vessel_volume, do: Code.new("122219", "DCM", "Vessel Volume")

  @spec wall_motion_score() :: Code.t()
  def wall_motion_score, do: Code.new("122307", "DCM", "Wall Motion Score")
end
