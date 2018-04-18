require 'linkeddata'
require 'date'
require 'securerandom'
require 'open-uri'
require 'nokogiri'
require 'csv'

ORG = RDF::Vocab::ORG
FOAF = RDF::Vocab::FOAF
SKOS = RDF::Vocab::SKOS
SCHEMA = RDF::Vocab::SCHEMA
DC = RDF::Vocab::DC
MU = RDF::Vocabulary.new("http://mu.semte.ch/vocabularies/core/")
PERSON = RDF::Vocabulary.new("http://www.w3.org/ns/person#")
PERSOON = RDF::Vocabulary.new("http://data.vlaanderen.be/ns/persoon#")
MANDAAT = RDF::Vocabulary.new("http://data.vlaanderen.be/ns/mandaat#")
BESLUIT = RDF::Vocabulary.new("http://data.vlaanderen.be/ns/besluit#")
EXT = RDF::Vocabulary.new("http://mu.semte.ch/vocabularies/ext/")

BASE_URI = "http://data.lblod.info/id/%{type}/%{id}"

def create_vestiging(contact_point)
  graph = RDF::Graph.new
  id = SecureRandom.uuid
  vestiging = RDF::URI(BASE_URI % {type: "vestiging", id: id })
  graph << RDF.Statement(vestiging, RDF.type, ORG.Site)
  graph << RDF.Statement(vestiging, MU.uuid, id)
  graph << RDF.Statement(vestiging, SCHEMA.contactPoint, contact_point)
  graph
end

def create_contactpoint(info)
  graph = RDF::Graph.new
  id = SecureRandom.uuid
  subject = RDF::URI(BASE_URI % {type: "contactpunt", id: id })
  graph << RDF.Statement(subject, RDF.type, SCHEMA.ContactPoint)
  graph << RDF.Statement(subject, MU.uuid, id)
  property_map = {
    country: SCHEMA.addressCountry,
    locality: SCHEMA.addressLocality,
    address: SCHEMA.streetAddress,
    postalCode: SCHEMA.postalCode,
    email: SCHEMA.email,
    telephone: SCHEMA.telephone,
    fax: SCHEMA.faxNumber,
    website: SCHEMA.url
  }
  property_map.each do |key, value|
    if info.key?(key) && info[key].length > 0
      graph << RDF.Statement(subject, property_map[key], info[key])
    end
  end
  graph
end

def create_politiezone(name, contact_point)
  graph = RDF::Graph.new
  id = SecureRandom.uuid
  subject = RDF::URI(BASE_URI % {type: "organisatie", id: id })
  graph << RDF.Statement(subject, RDF.type, ORG.Organization)
  graph << RDF.Statement(subject, MU.uuid, id)
  graph << RDF.Statement(subject, SKOS.prefLabel, name)
  graph << RDF.Statement(subject, SCHEMA.contactPoint, contact_point)
  graph
end

def create_position(person, role)
  graph = RDF::Graph.new
  id = SecureRandom.uuid
  subject = RDF::URI(BASE_URI % {type: "positie", id: id })
  graph << RDF.Statement(subject, RDF.type, ORG.Post)
  graph << RDF.Statement(subject, MU.uuid, id)
  graph << RDF.Statement(subject, ORG.heldBy, person)
  graph << RDF.Statement(subject, ORG.role, role)
  graph
end

def create_person(voornaam, achternaam)
  graph = RDF::Graph.new
  id = SecureRandom.uuid
  subject = RDF::URI(BASE_URI % {type: "persoon", id: id })
  graph  << RDF.Statement(subject, RDF.type, PERSON.Person)
  graph << RDF.Statement(subject, MU.uuid, id)
  graph << RDF.Statement(subject, FOAF.familyName, achternaam)
  graph << RDF.Statement(subject, PERSOON.gebruikteVoornaam, voornaam)
end

secretaris = RDF::URI("http://data.lblod.info/id/concept/bestuurseenheidRollen/66b95587-b24b-46a5-9231-b4dec06bddac")
adjunct_secretaris = RDF::URI("http://data.lblod.info/id/concept/bestuurseenheidRollen/8235802f-37fd-4971-826c-063205a1a31c")
financieel_beheerder = RDF::URI("http://data.lblod.info/id/concept/bestuurseenheidRollen/b83a1d0e-0390-4759-871a-e99c9ec00490")
informatie_ambtenaar = RDF::URI("http://data.lblod.info/id/concept/bestuurseenheidRollen/f5a7bf88-f31b-4ea8-926b-233b4952fe13")
zonechef = RDF::URI("http://data.lblod.info/id/concept/bestuurseenheidRollen/a2e91f2b-6353-4042-ba8c-71d0015ea1d1")

def create_person_from_concat_string(string)
  parts = string.to_s.split(' ')
  firstName = parts[0] || ""
  lastName = parts.length > 1 ? parts[1..parts.length].join(' ') : ""
  create_person(firstName, lastName)
end

def clean_phone(phone)
  phone = phone.to_s.gsub(' ','')
  if phone.start_with?('0')
    phone = "+32#{phone[1..phone.length]}"
  end
end

def clean_site(site)
  site = site.to_s
  if (site && site.length > 0 && ! site.start_with?('http'))
    site="http://#{site}"
  end
  site
end

gemeente_to_eenheid = Hash[CSV.read("map.csv", headers: true).map{|row| [row["label"], row["eenheid"]]}]

type = ARGV[0]
gemeente_nis_code = ARGV[1]
xml = Nokogiri::XML(open("http://mandatenbeheer-publicatie.vlaanderen.be/mdbPublication/data/MDB100/MDB100_%{type}_%{gemeente}.xml" % {gemeente: gemeente_nis_code, type: type}))
contact_point = create_contactpoint(locality: xml.xpath('/AllocationHistory/Council/CouncilCity/text()'),
                                    postalCode: xml.xpath('/AllocationHistory/Council/CouncilPostCode/text()'),
                                    address: xml.xpath('/AllocationHistory/Council/CouncilAddress/text()'),
                                    email: RDF::URI("mailto:#{xml.xpath('/AllocationHistory/Council/CouncilEmail/text()')}"),
                                    telephone: RDF::URI("tel:#{clean_phone(xml.xpath('/AllocationHistory/Council/CouncilTelephone/text()'))}"),
                                    fax: RDF::URI("tel:#{clean_phone(xml.xpath('/AllocationHistory/Council/CouncilFax/text()'))}"),
                                    website: RDF::URI("#{clean_site(xml.xpath('/AllocationHistory/Council/CouncilWebsiteUrl/text()'))}")
                                   )
vestiging = create_vestiging(contact_point.first.subject)

if type == "GE"
contact_police = create_contactpoint(locality: xml.xpath('/AllocationHistory/Council/PoliceZoneCity/text()'),
                                     postalCode: xml.xpath('/AllocationHistory/Council/PoliceZonePostCode/text()'),
                                     address: xml.xpath('/AllocationHistory/Council/PoliceZoneAddress/text()')
                                    )
politiezone = create_politiezone(xml.xpath('/AllocationHistory/Council/PoliceZoneName/text()'), contact_police.first.subject)

secretary = create_person_from_concat_string(xml.xpath('/AllocationHistory/Council/CouncilSecretary/text()'))
adjunct_secretary = create_person_from_concat_string(xml.xpath('/AllocationHistory/Council/CouncilAdjunctSecretary/text()'))
financial_manager = create_person_from_concat_string(xml.xpath('/AllocationHistory/Council/CouncilFinancialManager/text()'))
information_officer = create_person_from_concat_string(xml.xpath('/AllocationHistory/Council/ConcilInformationManager/text()'))
police_zone_chief = create_person_from_concat_string(xml.xpath('/AllocationHistory/Council/PoliceZoneChiefname/text()'))

secretaris_gemeente = create_position(secretary.first.subject, secretaris)
adjunct_secretaris_gemeente = create_position(adjunct_secretary.first.subject, adjunct_secretaris)
financieel_beheerder_gemeente = create_position(financial_manager.first.subject, financieel_beheerder)
informatie_ambtenaar_gemeente = create_position(information_officer.first.subject, informatie_ambtenaar)
zonechef_gemeente = create_position(police_zone_chief.first.subject, zonechef)
end

gemeente_naam = xml.xpath('/AllocationHistory/Council/GeoUnit/text()').to_s
gemeente = RDF::URI(gemeente_to_eenheid[gemeente_naam])
RDF::Writer.open("#{DateTime.now.strftime("%Y%m%d%H%M%S")}-administratieve-gegevens-#{type}-#{gemeente_naam}-#{gemeente_nis_code}.ttl") do |writer|
  writer << contact_point
  writer << vestiging
  if type == "GE"
      writer << contact_police
      writer << politiezone
      writer << secretary
      writer << adjunct_secretary
      writer << financial_manager
      writer << information_officer
      writer << police_zone_chief
      writer << secretaris_gemeente
      writer << adjunct_secretaris_gemeente
      writer << financieel_beheerder_gemeente
      writer << informatie_ambtenaar_gemeente
      writer << zonechef_gemeente
      writer << RDF.Statement(gemeente, ORG.hasPrimarySite, vestiging.first.subject)
      writer << RDF.Statement(gemeente, ORG.hasPost, secretaris_gemeente.first.subject)
      writer << RDF.Statement(gemeente, ORG.hasPost, adjunct_secretaris_gemeente.first.subject)
      writer << RDF.Statement(gemeente, ORG.hasPost, financieel_beheerder_gemeente.first.subject)
      writer << RDF.Statement(gemeente, ORG.hasPost, informatie_ambtenaar_gemeente.first.subject)
      writer << RDF.Statement(gemeente, ORG.linkedTo, politiezone.first.subject)
      writer << RDF.Statement(politiezone.first.subject, ORG.hasPost, zonechef_gemeente.first.subject)
  end
end
