
-- =============================================
-- Author: TeploukhovES 
-- Create date: 20.08.2021
-- Pbi: http://eka-devops/devops/Sinara/DAX/_workitems/edit/10988
-- Description: Сводный технический акт П-1 с пробегами
-- Change 23.11.2021 http://eka-devops/devops/Sinara/DAX/_workitems/edit/11959
-- Change 10.01.2022 http://eka-devops/devops/Sinara/DAX/_workitems/edit/11880
-- Change 02.10.2022 http://eka-devops/devops/Sinara/DAX/_workitems/edit/12766
-- Change 03.10.2022 http://eka-devops/devops/Sinara/DAX/_workitems/edit/13390
-- =============================================
ALTER VIEW [$(PROJECT_SCHEMA_NAME)].V_PBI_10988_TECHNICAL_ACT_P1
AS
	SELECT
		techActAsut.[Серия локомотива],
		techActAsut.[Номер Локомотива],
		techActAsut.[Кол-во секций],
		techActAsut.[Дата постановки локомотива в ремонт],
		techActAsut.[Время постановки локомотива в ремонт],
		techActAsut.[№ Акта приемки Локомотива в ремонт],
		techActAsut.[Вид ремонта],
		techActAsut.[Дата выхода локомотива из ремонта],
		techActAsut.[Время выхода локомотива из ремонта],
		techActAsut.[№ Акта приемки Локомотива из ремонта],
		techActAsut.[Кол-во нахождения в ремонте одной секции],
		techActAsut.[Кол-во нахождения всех секций в ремонте(суммарно)],
		techActAsut.[Депо приписки(Примечание)],
		techActAsut.[Пробег на момент постановки локомотива на СО от последнего аналогичного ремонта],
		techActAsut.[Код журнала прибытия],
		techActAsut.[Фильтр подразделения],
		techActAsut.[Фильтр даты],
		techActAsut.[Заказчик],
		techActAsut.[Исполнитель],
		techActAsut.[Сортировка даты и времени]
	FROM [$(PROJECT_SCHEMA_NAME)].V_PBI_10988_TECHNICAL_ACT_P1_ASUT_DATE AS techActAsut

	UNION ALL

	SELECT
		techActActual.[Серия локомотива],
		techActActual.[Номер Локомотива],
		techActActual.[Кол-во секций],
		techActActual.[Дата постановки локомотива в ремонт],
		techActActual.[Время постановки локомотива в ремонт],
		techActActual.[№ Акта приемки Локомотива в ремонт],
		techActActual.[Вид ремонта],
		techActActual.[Дата выхода локомотива из ремонта],
		techActActual.[Время выхода локомотива из ремонта],
		techActActual.[№ Акта приемки Локомотива из ремонта],
		techActActual.[Кол-во нахождения в ремонте одной секции],
		techActActual.[Кол-во нахождения всех секций в ремонте(суммарно)],
		techActActual.[Депо приписки(Примечание)],
		techActActual.[Пробег на момент постановки локомотива на СО от последнего аналогичного ремонта],
		techActActual.[Код журнала прибытия],
		techActActual.[Фильтр подразделения],
		techActActual.[Фильтр даты],
		techActActual.[Заказчик],
		techActActual.[Исполнитель],
		techActActual.[Сортировка даты и времени]
	FROM [$(PROJECT_SCHEMA_NAME)].V_PBI_10988_TECHNICAL_ACT_P1_ACTUAL_DATE AS techActActual
GO